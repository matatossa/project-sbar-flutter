import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/lesson.dart';
import '../widgets/app_navbar.dart';
import 'dart:async';
import '../services/lesson_service.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

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
  Lesson? currentLesson; // Store current lesson to allow updates

  @override
  void initState() {
    super.initState();
    currentLesson = widget.lesson;
    _loadVideo();
    _parseTranscript();
    _checkEnrollment();
  }

  Future<void> _refreshLesson() async {
    final updatedLesson = await LessonService.fetchLessonById(widget.lesson.id, context);
    if (updatedLesson != null && mounted) {
      setState(() {
        currentLesson = updatedLesson;
      });
      _parseTranscript();
    }
  }

  void _loadVideo() {
    if (widget.lesson.videoUrl != null && widget.lesson.videoUrl!.isNotEmpty) {
      setState(() => isLoadingVideo = true);
      final backendStreamUrl = 'http://localhost:8080/api/lessons/${widget.lesson.id}/stream';
      print('Loading video from: $backendStreamUrl');

      // For web, we need to ensure proper headers are sent
      _controller = VideoPlayerController.network(
        backendStreamUrl,
        httpHeaders: {
          'Accept': 'video/mp4, video/webm, video/ogg, */*',
          'Range': 'bytes=0-',
        },
      );

      _controller!.initialize().then((_) {
        print('Video initialized successfully');
        setState(() {
          isLoadingVideo = false;
        });
      }).catchError((error) {
        setState(() {
          isLoadingVideo = false;
        });
        print('Video load error: $error');
        print('Error type: ${error.runtimeType}');
        if (error.toString().contains('MEDIA_ERR_SRC_NOT_SUPPORTED')) {
          print('ERROR: Video format not supported by browser.');
          print('The video must be in H.264/AAC format in an MP4 container for web playback.');
          print('Original video URL: ${widget.lesson.videoUrl}');
        }
      });
      _controller!.addListener(_onVideoProgress);
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _highlightWord());
    }
  }

  void _checkEnrollment() async {
    // Check if user is enrolled by checking my courses
    final myCourses = await LessonService.fetchMyCourses(context);
    if (mounted) {
      setState(() {
        enrolled = myCourses.any((c) => c.id == widget.lesson.id);
      });
    }
  }

  void _parseTranscript() {
    final lesson = currentLesson ?? widget.lesson;
    print('=== TRANSCRIPT DEBUG ===');
    print('Transcript value: ${lesson.transcript}');
    print('Transcript is null: ${lesson.transcript == null}');
    print('Transcript is empty: ${lesson.transcript?.isEmpty ?? true}');

    wordTimings = null; // reset

    if (lesson.transcript != null && lesson.transcript!.isNotEmpty) {
      // If backend stored an empty array string "[]", treat as no transcript
      final trimmed = lesson.transcript!.trim();
      if (trimmed == '[]') {
        print('Transcript is an empty list "[]", treating as no transcript');
        return;
      }

      try {
        final parsed = jsonDecode(lesson.transcript!);
        if (parsed is List && parsed.isNotEmpty) {
          // convert to List<Map<String, dynamic>>
          wordTimings = List<Map<String, dynamic>>.from(parsed.map((e) => Map<String, dynamic>.from(e)));
          print('Parsed as word timings list with ${wordTimings!.length} words');
          return;
        } else {
          print('Parsed JSON is a list but empty or not useful: $parsed');
        }
      } catch (e) {
        print('Failed to parse as JSON: $e');
      }

      // fallback: make a fake dummy timings list from plain text
      final words = lesson.transcript!.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.isNotEmpty) {
        double t = 0.0;
        wordTimings = words.map((w) => {"word": w, "start": t, "end": t += 0.5}).toList();
        print('Created word timings from plain text with ${wordTimings!.length} words');
      } else {
        print('Transcript present but produced no words after splitting.');
      }
    } else {
      print('No transcript available');
    }
  }

  void _onVideoProgress() {
    setState(() {}); // triggers a rebuild
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

  @override
  void dispose() {
    _controller?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool _isAdmin(AuthService authService) {
    // Null-safe check for admin role, matches ROLE_ADMIN, admin, Admin, etc.
    final role = (authService.userRole ?? '').toUpperCase();
    return role.contains('ADMIN');
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // debug print to confirm what the app has for role
    print('🔍 Flutter sees userRole = "${authService.userRole}"');

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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lesson.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C1D1F)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.lesson.description,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF6A6F73), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (widget.lesson.videoUrl != null && widget.lesson.videoUrl!.isNotEmpty) ...[
              if (isLoadingVideo)
                Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                )
              else if (_controller != null && _controller!.value.isInitialized)
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                    minHeight: 400,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                )
              else
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        const Text('Video unavailable', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _loadVideo(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_controller != null && _controller!.value.isInitialized)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_controller!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: () {
                          setState(() {
                            _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                          });
                        },
                      ),
                      Expanded(
                        child: VideoProgressIndicator(_controller!, allowScrubbing: true),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.video_file_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No video available for this lesson yet', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Transcript section - always show when video exists, even if transcript is empty
            if ((currentLesson ?? widget.lesson).videoUrl != null && (currentLesson ?? widget.lesson).videoUrl!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transcript',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1C1D1F)),
                    ),
                    const SizedBox(height: 16),
                    if ((currentLesson ?? widget.lesson).transcript != null && (currentLesson ?? widget.lesson).transcript!.isNotEmpty && (currentLesson ?? widget.lesson).transcript!.trim() != '[]') ...[
                      if (wordTimings != null && wordTimings!.isNotEmpty)
                        // Word-by-word transcript with highlighting
                        Wrap(
                          spacing: 4,
                          runSpacing: 6,
                          children: [
                            for (int i = 0; i < wordTimings!.length; i++)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: i == currentWordIdx
                                      ? const Color(0xFF0056D2).withOpacity(0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: i == currentWordIdx
                                      ? Border.all(color: const Color(0xFF0056D2), width: 1.5)
                                      : null,
                                ),
                                child: Text(
                                  wordTimings![i]['word'] ?? '',
                                  style: TextStyle(
                                    fontWeight: i == currentWordIdx ? FontWeight.bold : FontWeight.normal,
                                    color: i == currentWordIdx ? const Color(0xFF0056D2) : const Color(0xFF1C1D1F),
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                          ],
                        )
                      else
                        // Plain text transcript fallback
                        Text(
                          (currentLesson ?? widget.lesson).transcript!,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1C1D1F),
                            height: 1.6,
                          ),
                        ),
                    ] else ...[
                      // Show message if no transcript with generate button for admins
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No transcript available for this lesson yet.',
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
                                onPressed: isGeneratingTranscript ? null : () async {
                                  setState(() {
                                    isGeneratingTranscript = true;
                                  });

                                  final success = await LessonService.triggerTranscript(widget.lesson.id, context);

                                  if (mounted) {
                                    if (success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Transcript generation started. This may take a few minutes...'),
                                          duration: Duration(seconds: 3),
                                        ),
                                      );

                                      // Wait a bit then refresh
                                      await Future.delayed(const Duration(seconds: 2));
                                      await _refreshLesson();

                                      // Keep checking for transcript
                                      for (int i = 0; i < 10; i++) {
                                        await Future.delayed(const Duration(seconds: 3));
                                        await _refreshLesson();
                                        final lesson = currentLesson ?? widget.lesson;
                                        if (lesson.transcript != null && lesson.transcript!.isNotEmpty && lesson.transcript!.trim() != '[]') {
                                          break;
                                        }
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Failed to start transcript generation. Please try again.'),
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
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                    : const Icon(Icons.transcribe),
                                label: Text(isGeneratingTranscript ? 'Generating...' : 'Generate Transcript'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0056D2),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  if (_isAdmin(authService)) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await LessonService.deleteLesson(widget.lesson.id, context);
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
                            final ok = await LessonService.enrollInLesson(widget.lesson.id, context);
                            if (ok && mounted) {
                              setState(() => enrolled = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Enrolled successfully!')),
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Enrollment failed')),
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
                          onPressed: watched ? null : () async {
                            final ok = await LessonService.markLessonWatched(widget.lesson.id, context);
                            if (ok && mounted) setState(() => watched = true);
                          },
                          icon: Icon(watched ? Icons.check_circle : Icons.play_circle_outline),
                          label: Text(watched ? 'Completed' : 'Mark as Completed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: watched ? Colors.green : const Color(0xFF0056D2),
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
