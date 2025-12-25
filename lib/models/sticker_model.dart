class StickerModel {
  final String id;
  final String label;
  final String imagePath;
  final String musicUrl;
  final DateTime collectedAt;

  StickerModel({
    required this.id,
    required this.label,
    required this.imagePath,
    required this.musicUrl,
    required this.collectedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'imageUrl': imagePath,
      'musicUrl': musicUrl,
      'collectedAt': collectedAt.toIso8601String(),
    };
  }

  factory StickerModel.fromJson(Map<String, dynamic> json) {
    return StickerModel(
      id: json['id'],
      label: json['label'],
      imagePath: json['imageUrl'],
      musicUrl: json['musicUrl'],
      collectedAt: DateTime.parse(json['collectedAt']),
    );
  }
}
