class Video {
  final int id;
  final String title;
  final String url;
  final int durationSec;

  Video({
    required this.id,
    required this.title,
    required this.url,
    required this.durationSec,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] ?? 0,
      title: (json['title'] as String?)?.isNotEmpty == true ? json['title'] : 'Vidéo sans titre',
      url: json['url'] ?? '',
      durationSec: json['durationSec'] ?? 0,
    );
  }
}
