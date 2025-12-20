import 'video.dart';

class Lesson {
  final int id;
  final String title;
  final String description;
  final String? videoUrl; // Legacy field - kept for backward compatibility
  final String? transcript; // Legacy field - kept for backward compatibility
  final int durationSec;
  final List<Video>? videos; // List of videos for this course

  Lesson({
    required this.id,
    required this.title,
    required this.description,
    this.videoUrl,
    this.transcript,
    required this.durationSec,
    this.videos,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    List<Video>? videosList;
    if (json['videos'] != null) {
      videosList = (json['videos'] as List)
          .map((v) => Video.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    
    return Lesson(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      videoUrl: json['videoUrl'],
      transcript: json['transcript'],
      durationSec: json['durationSec'] ?? 0,
      videos: videosList,
    );
  }
}

