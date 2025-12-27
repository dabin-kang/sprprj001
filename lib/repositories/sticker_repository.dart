import 'dart:io';
import '../models/sticker_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StickerRepository {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;
  static final _auth = FirebaseAuth.instance;

  /// ===============================
  /// 스티커 수집 (중복 방지 + Storage + Firestore)
  /// ===============================
  static Future<void> add({
    required String id,
    required String label,
    required File imageFile,
    required String musicUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다');

    final uid = user.uid;

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('stickers')
        .doc(id);

    // 🔴 중복 방지
    final exists = await docRef.get();
    if (exists.exists) {
      throw Exception('이미 수집한 스티커입니다');
    }

    // 🔴 Storage 업로드
    final storageRef = _storage.ref('stickers/$uid/$id.jpg');
    await storageRef.putFile(imageFile);
    final imageUrl = await storageRef.getDownloadURL();

    // 🔴 Firestore 저장
    await docRef.set({
      'label': label,
      'imageUrl': imageUrl,
      'musicUrl': musicUrl,
      'collectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ===============================
  /// 스티커북 조회
  /// ===============================
  static Future<List<StickerModel>> getAll() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다');

    final uid = user.uid;

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('stickers')
        .orderBy('collectedAt', descending: true)
        .get();

    return snapshot.docs.map<StickerModel>((doc) {
      return StickerModel(
        id: doc.id,
        label: doc['label'],
        imageUrl: doc['imageUrl'],
        musicUrl: doc['musicUrl'],
        collectedAt: doc['collectedAt'],
      );
    }).toList();
  }
}
