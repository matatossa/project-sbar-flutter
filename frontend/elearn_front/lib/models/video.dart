class Video {
  final int id;
  final String title;
  final String? videoUrl;
  final String? transcript;
  final int durationSec;
  final int orderIndex;

  Video({
    required this.id,
    required this.title,
    this.videoUrl,
    this.transcript,
    required this.durationSec,
    required this.orderIndex,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      videoUrl: json['videoUrl'],
      transcript: json['transcript'],
      durationSec: json['durationSec'] ?? 0,
      orderIndex: json['orderIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'videoUrl': videoUrl,
      'transcript': transcript,
      'durationSec': durationSec,
      'orderIndex': orderIndex,
    };
  }
}






