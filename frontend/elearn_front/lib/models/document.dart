class Document {
  final int id;
  final String title;
  final String? fileUrl;
  final String? description;
  final int orderIndex;

  Document({
    required this.id,
    required this.title,
    this.fileUrl,
    this.description,
    required this.orderIndex,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      fileUrl: json['fileUrl'],
      description: json['description'],
      orderIndex: json['orderIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'fileUrl': fileUrl,
      'description': description,
      'orderIndex': orderIndex,
    };
  }
}




