import 'package:cloud_firestore/cloud_firestore.dart';

class StickerModel {
  final String id;
  final String label;
  final String imageUrl;
  final String musicUrl;
  final Timestamp? collectedAt;

  StickerModel({
    required this.id,
    required this.label,
    required this.imageUrl,
    required this.musicUrl,
    this.collectedAt,
  });

  /// Firestore → Model
  factory StickerModel.fromJson(String id, Map<String, dynamic> json) {
    return StickerModel(
      id: id,
      label: json['label'],
      imageUrl: json['imageUrl'],
      musicUrl: json['musicUrl'],
      collectedAt: json['collectedAt'],
    );
  }

  /// Model → Firestore
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'imageUrl': imageUrl,
      'musicUrl': musicUrl,
      'collectedAt': collectedAt,
    };
  }
}
