// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';

import '../models/lesson.dart';
import '../models/video.dart';
import '../models/document.dart';
import '../widgets/app_navbar.dart';
import '../widgets/sidebar_nav.dart';
import '../services/lesson_service.dart';
import '../services/auth_service.dart';
import 'content_item.dart';
import 'pdf_viewer_screen.dart';

class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;
  const LessonDetailScreen({Key? key, required this.lesson}) : super(key: key);

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  VideoPlayerController? _controller;
  Timer? _timer;

  List<Map<String, dynamic>>? wordTimings;
  int? currentWordIdx;

  bool watched = false;
  bool enrolled = false;
  bool isLoadingVideo = false;
  bool isGeneratingTranscript = false;
  bool isLoadingVideos = false;
  bool isLoadingDocuments = false;
  String? videoError;

  Lesson? currentLesson;
  List<Video> videos = [];
  List<Document> documents = [];
  Video? selectedVideo;

  @override
  void initState() {
    super.initState();
    currentLesson = widget.lesson;
    _loadVideos();
    _loadDocuments();
    _checkEnrollment();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      isLoadingDocuments = true;
    });
    try {
      final fetchedDocuments =
          await LessonService.fetchDocumentsByLesson(widget.lesson.id, context);

      if (!mounted) return;

      setState(() {
        documents = fetchedDocuments;
        isLoadingDocuments = false;
      });
    } catch (e) {
      print('Error loading documents: $e');
      if (!mounted) return;
      setState(() {
        isLoadingDocuments = false;
      });
    }
  }

  Future<void> _loadVideos() async {
    setState(() {
      isLoadingVideos = true;
      videoError = null;
    });
    try {
      final fetchedVideos =
          await LessonService.fetchVideosByLesson(widget.lesson.id, context);

      if (!mounted) return;

      setState(() {
        videos = fetchedVideos;
        isLoadingVideos = false;

        if (videos.isNotEmpty) {
          selectedVideo = videos.first;
          _loadVideo(selectedVideo);
        } else if (widget.lesson.videoUrl?.isNotEmpty == true) {
          _loadVideo(null);
        }
      });
    } catch (e) {
      print('Error loading videos: $e');
      if (!mounted) return;
      setState(() {
        isLoadingVideos = false;
        videoError = 'Failed to load videos: $e';
      });
    }
  }

  Future<void> _refreshLesson() async {
    final updatedLesson =
        await LessonService.fetchLessonById(widget.lesson.id, context);
    if (updatedLesson != null && mounted) {
      setState(() {
        currentLesson = updatedLesson;
      });
      await _loadVideos();
      await _loadDocuments();
    }
  }

  void _loadVideo(Video? video) {
    _controller?.dispose();
    _timer?.cancel();

    String? videoUrl;
    if (video != null && video.videoUrl?.isNotEmpty == true) {
      videoUrl = video.videoUrl;
      setState(() {
        selectedVideo = video;
        videoError = null;
      });
      _parseTranscript(video.transcript);
    } else if (widget.lesson.videoUrl?.isNotEmpty == true) {
      videoUrl = widget.lesson.videoUrl;
      setState(() {
        selectedVideo = null;
        videoError = null;
      });
      _parseTranscript(widget.lesson.transcript);
    } else {
      setState(() {
        videoError = 'No video available';
      });
      return;
    }

    setState(() {
      isLoadingVideo = true;
      videoError = null;
    });

    final backendUrl = video != null
        ? 'http://localhost:8080/api/videos/${video.id}/stream'
        : 'http://localhost:8080/api/lessons/${widget.lesson.id}/stream';

    print('Loading video from: $backendUrl');

    _controller = VideoPlayerController.network(
      backendUrl,
      httpHeaders: {
        'Accept': 'video/mp4, video/webm, video/ogg, */*',
        'Range': 'bytes=0-',
      },
    );

    _controller!.initialize().then((_) {
      print('Video initialized successfully');
      if (mounted) {
        setState(() {
          isLoadingVideo = false;
        });
      }
    }).catchError((error) {
      print('Video load error: $error');
      if (mounted) {
        setState(() {
          isLoadingVideo = false;
          videoError = 'Failed to load video: ${error.toString()}';
        });
      }
    });

    _controller!.addListener(_onVideoProgress);
    _timer =
        Timer.periodic(const Duration(milliseconds: 200), (_) => _highlightWord());
  }

  void _parseTranscript(String? transcriptText) {
    wordTimings = null;

    if (transcriptText == null || transcriptText.trim().isEmpty) return;

    try {
      final parsed = jsonDecode(transcriptText);
      if (parsed is List && parsed.isNotEmpty) {
        wordTimings = List<Map<String, dynamic>>.from(
          parsed.map((e) => Map<String, dynamic>.from(e)),
        );
        return;
      }
    } catch (_) {}

    final words =
        transcriptText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    double t = 0.0;
    wordTimings =
        words.map((w) => {"word": w, "start": t, "end": t += 0.5}).toList();
  }

  void _onVideoProgress() {
    setState(() {});
  }

  void _highlightWord() {
    if (_controller == null || wordTimings == null || wordTimings!.isEmpty) return;

    final curT = _controller!.value.position.inMilliseconds / 1000.0;
    for (int i = 0; i < wordTimings!.length; i++) {
      final start = (wordTimings![i]["start"] ?? 0).toDouble();
      final end = (wordTimings![i]["end"] ?? start + 0.4).toDouble();
      if (curT >= start && curT <= end) {
        if (currentWordIdx != i) setState(() => currentWordIdx = i);
        return;
      }
    }
    if (currentWordIdx != null) setState(() => currentWordIdx = null);
  }

  void _checkEnrollment() async {
    final myCourses = await LessonService.fetchMyCourses(context);
    if (!mounted) return;
    setState(() {
      enrolled = myCourses.any((c) => c.id == widget.lesson.id);
    });
  }

  bool _isAdmin(AuthService auth) =>
      (auth.userRole ?? '').toUpperCase().contains('ADMIN');

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  String _formatDurationForDisplay(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')} min';
  }

  String _formatTotalDuration() {
    final totalSeconds = videos.fold<int>(0, (sum, video) => sum + video.durationSec);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hour${hours > 1 ? 's' : ''}';
    }
    return '$minutes min';
  }

  List<Widget> _buildContentList() {
    final List<Widget> items = [];
    int index = 1;

    // Add videos
    for (final video in videos) {
      final isSelected = selectedVideo?.id == video.id;
      items.add(ContentItem(
        index: index++,
        title: video.title.isNotEmpty ? video.title : 'Video ${index - 1}',
        description: 'Video lecture',
        duration: _formatDurationForDisplay(video.durationSec),
        type: ContentType.video,
        isSelected: isSelected,
        onTap: () => _loadVideo(video),
        onDelete: _isAdmin(Provider.of<AuthService>(context, listen: false))
            ? () => _deleteVideo(video)
            : null,
      ));
    }

    // Add documents
    for (final document in documents) {
      items.add(ContentItem(
        index: index++,
        title: document.title,
        description: document.description ?? 'Readable course material',
        duration: null,
        type: ContentType.document,
        isSelected: false,
        onTap: () => _downloadDocument(document),
        onDelete: _isAdmin(Provider.of<AuthService>(context, listen: false))
            ? () => _deleteDocument(document)
            : null,
      ));
    }

    return items;
  }

  Future<void> _addVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.size == 0) return;

      setState(() {
        isLoadingVideos = true;
      });

      final success = await LessonService.uploadVideoToLesson(
        widget.lesson.id,
        file,
        context,
      );

      if (mounted) {
        setState(() {
          isLoadingVideos = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video uploaded successfully')),
          );
          await _loadVideos();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload video'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error adding video: $e');
      if (mounted) {
        setState(() {
          isLoadingVideos = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteVideo(Video video) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: Text('Are you sure you want to delete "${video.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isLoadingVideos = true;
    });

    final success =
        await LessonService.deleteVideo(video.id, context);

    if (mounted) {
      setState(() {
        isLoadingVideos = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video deleted')),
        );
        await _loadVideos();
        if (selectedVideo?.id == video.id) {
          if (videos.isNotEmpty) {
            _loadVideo(videos.first);
          } else if (widget.lesson.videoUrl?.isNotEmpty == true) {
            _loadVideo(null);
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete video'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.size == 0) return;

      // Show dialog for description
      final description = await showDialog<String>(
        context: context,
        builder: (context) {
          String? desc = '';
          return AlertDialog(
            title: const Text('Add Document'),
            content: TextField(
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Enter a description for this document',
              ),
              onChanged: (value) => desc = value,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, desc),
                child: const Text('Add'),
              ),
            ],
          );
        },
      );

      setState(() {
        isLoadingDocuments = true;
      });

      final success = await LessonService.uploadDocumentToLesson(
        widget.lesson.id,
        file,
        description,
        context,
      );

      if (mounted) {
        setState(() {
          isLoadingDocuments = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded successfully')),
          );
          await _loadDocuments();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload document'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error adding document: $e');
      if (mounted) {
        setState(() {
          isLoadingDocuments = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(Document document) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${document.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isLoadingDocuments = true;
    });

    final success = await LessonService.deleteDocument(document.id, context);

    if (mounted) {
      setState(() {
        isLoadingDocuments = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted')),
        );
        await _loadDocuments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete document'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _downloadDocument(Document document) {
    // Always use the backend download endpoint with inline=true for proper authentication
    final pdfUrl = 'http://localhost:8080/api/documents/${document.id}/download?inline=true';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          pdfUrl: pdfUrl,
          title: document.title,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final transcriptText =
        selectedVideo?.transcript ?? widget.lesson.transcript;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: AppNavbar(
        title: widget.lesson.title.length > 40
            ? '${widget.lesson.title.substring(0, 40)}...'
            : widget.lesson.title,
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lesson Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lesson.title,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1D1F)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.lesson.description,
                    style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6A6F73),
                        height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Video List Section (if multiple videos)
            if (videos.length > 1) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Videos',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1C1D1F)),
                        ),
                        if (_isAdmin(authService))
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _addVideo,
                            tooltip: 'Add Video',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...videos.asMap().entries.map((entry) {
                      final index = entry.key;
                      final video = entry.value;
                      final isSelected = selectedVideo?.id == video.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0056D2).withOpacity(0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF0056D2)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0056D2)
                                  : Colors.grey[400],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          title: Text(
                            video.title.isNotEmpty
                                ? video.title
                                : 'Video ${index + 1}',
                            style: TextStyle(
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xFF0056D2)
                                  : const Color(0xFF1C1D1F),
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                _formatDuration(video.durationSec),
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          trailing: _isAdmin(authService)
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () => _deleteVideo(video),
                                )
                              : isSelected
                                  ? const Icon(Icons.check_circle,
                                      color: Color(0xFF0056D2))
                                  : null,
                          onTap: () => _loadVideo(video),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Admin: Add Video button (if single or no videos)
            if (_isAdmin(authService) && videos.length <= 1) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Videos',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1D1F)),
                    ),
                    ElevatedButton.icon(
                      onPressed: isLoadingVideos ? null : _addVideo,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Video'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0056D2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Video Player Section
            if (isLoadingVideos)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (videos.isNotEmpty ||
                (widget.lesson.videoUrl != null &&
                    widget.lesson.videoUrl!.isNotEmpty)) ...[
              if (isLoadingVideo)
                Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                )
              else if (videoError != null)
                Container(
                  height: 300,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 8),
                        Text(
                          videoError!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (selectedVideo != null) {
                              _loadVideo(selectedVideo);
                            } else {
                              _loadVideo(null);
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_controller != null &&
                  _controller!.value.isInitialized)
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.6,
                        minHeight: 400,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(_controller!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow),
                            onPressed: () {
                              setState(() {
                                _controller!.value.isPlaying
                                    ? _controller!.pause()
                                    : _controller!.play();
                              });
                            },
                          ),
                          Expanded(
                            child: VideoProgressIndicator(_controller!,
                                allowScrubbing: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_file_outlined,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Video loading...',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
            ] else ...[
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.video_file_outlined,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No video available for this lesson yet',
                          style: TextStyle(color: Colors.grey)),
                      if (_isAdmin(authService)) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _addVideo,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Video'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Transcript Section (moved above Course Content)
            if (selectedVideo != null ||
                (widget.lesson.videoUrl != null &&
                    widget.lesson.videoUrl!.isNotEmpty)) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transcript',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1D1F)),
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        if (transcriptText != null &&
                            transcriptText.isNotEmpty &&
                            transcriptText.trim() != '[]') {
                          if (wordTimings != null &&
                              wordTimings!.isNotEmpty) {
                            return Wrap(
                              spacing: 4,
                              runSpacing: 6,
                              children: [
                                for (int i = 0; i < wordTimings!.length; i++)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: i == currentWordIdx
                                          ? const Color(0xFF0056D2)
                                              .withOpacity(0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                      border: i == currentWordIdx
                                          ? Border.all(
                                              color: const Color(0xFF0056D2),
                                              width: 1.5)
                                          : null,
                                    ),
                                    child: Text(
                                      wordTimings![i]['word'] ?? '',
                                      style: TextStyle(
                                        fontWeight: i == currentWordIdx
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: i == currentWordIdx
                                            ? const Color(0xFF0056D2)
                                            : const Color(0xFF1C1D1F),
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          } else {
                            return Text(
                              transcriptText,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF1C1D1F),
                                height: 1.6,
                              ),
                            );
                          }
                        }

                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.grey[600], size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No transcript available for this video yet.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_isAdmin(authService)) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isGeneratingTranscript
                                      ? null
                                      : () async {
                                          setState(() {
                                            isGeneratingTranscript = true;
                                          });

                                          bool success = false;
                                          if (selectedVideo != null) {
                                            final authService =
                                                Provider.of<AuthService>(context,
                                                    listen: false);
                                            final response = await http.post(
                                              Uri.parse(
                                                  'http://localhost:8080/api/videos/${selectedVideo!.id}/transcript'),
                                              headers: {
                                                'Authorization':
                                                    'Bearer ${authService.jwt}'
                                              },
                                            );
                                            success = response.statusCode == 200;
                                          } else {
                                            success = await LessonService
                                                .triggerTranscript(
                                              widget.lesson.id,
                                              context,
                                            );
                                          }

                                          if (mounted) {
                                            if (success) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Transcript generation started. This may take a few minutes...'),
                                                  duration:
                                                      Duration(seconds: 3),
                                                ),
                                              );

                                              await Future.delayed(
                                                  const Duration(seconds: 2));
                                              await _refreshLesson();

                                              for (int i = 0; i < 10; i++) {
                                                await Future.delayed(
                                                    const Duration(seconds: 3));
                                                await _refreshLesson();
                                                final lesson =
                                                    currentLesson ??
                                                        widget.lesson;
                                                if (lesson.transcript != null &&
                                                    lesson.transcript!
                                                        .isNotEmpty &&
                                                    lesson.transcript!
                                                            .trim() !=
                                                        '[]') {
                                                  break;
                                                }
                                              }
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Failed to start transcript generation. Please try again.'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                            setState(() {
                                              isGeneratingTranscript = false;
                                            });
                                          }
                                        },
                                  icon: isGeneratingTranscript
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.transcribe),
                                  label: Text(isGeneratingTranscript
                                      ? 'Generating...'
                                      : 'Generate Transcript'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0056D2),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Course Content Section (Videos + PDFs) - moved below Transcript
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Course\'s content',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1C1D1F)),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${videos.length + documents.length} ${videos.length + documents.length == 1 ? 'lecture' : 'lectures'} • ${_formatTotalDuration()}',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      if (_isAdmin(authService))
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.video_library, color: Color(0xFFFF6B35)),
                              onPressed: _addVideo,
                              tooltip: 'Add Video',
                            ),
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFFF6B35)),
                              onPressed: _addDocument,
                              tooltip: 'Add PDF',
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isLoadingVideos || isLoadingDocuments)
                    const Center(child: CircularProgressIndicator())
                  else if (videos.isEmpty && documents.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'No content yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._buildContentList(),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  if (_isAdmin(authService)) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await LessonService.deleteLesson(
                              widget.lesson.id, context);
                          if (ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Course deleted')),
                            );
                            Navigator.pop(context, true);
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Delete failed')),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Course'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ] else ...[
                    if (!enrolled)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final ok = await LessonService.enrollInLesson(
                                widget.lesson.id, context);
                            if (ok && mounted) {
                              setState(() => enrolled = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Enrolled successfully!')),
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Enrollment failed')),
                              );
                            }
                          },
                          icon: const Icon(Icons.person_add),
                          label: const Text('S\'inscrire'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0056D2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    if (enrolled) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: watched
                              ? null
                              : () async {
                                  final ok = await LessonService
                                      .markLessonWatched(
                                          widget.lesson.id, context);
                                  if (ok && mounted)
                                    setState(() => watched = true);
                                },
                          icon: Icon(watched
                              ? Icons.check_circle
                              : Icons.play_circle_outline),
                          label: Text(watched
                              ? 'Completed'
                              : 'Mark as Completed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                watched ? Colors.green : const Color(0xFF0056D2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
