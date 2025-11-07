class Lesson {
  final int id;
  final String title;
  final String description;
  final String? videoUrl;
  final String? transcript;
  final int durationSec;

  Lesson({
    required this.id,
    required this.title,
    required this.description,
    this.videoUrl,
    this.transcript,
    required this.durationSec,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      videoUrl: json['videoUrl'],
      transcript: json['transcript'],
      durationSec: json['durationSec'] ?? 0,
    );
  }
}

