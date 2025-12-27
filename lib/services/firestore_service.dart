import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ===============================
  /// 스티커 저장 (중복 방지)
  /// ===============================
  Future<void> saveSticker({
    required String stickerId,
    required String label,
    required String imageUrl,
    required String musicUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다');
    }

    final uid = user.uid;

    // 🔹 유저 문서 생성 (없으면)
    await _db.collection('users').doc(uid).set({
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final stickerRef = _db
        .collection('users')
        .doc(uid)
        .collection('stickers')
        .doc(stickerId);

    // 🔴 중복 수집 방지
    final exists = await stickerRef.get();
    if (exists.exists) {
      throw Exception('이미 수집한 스티커입니다');
    }

    // 🔹 스티커 저장
    await stickerRef.set({
      'label': label,
      'imageUrl': imageUrl,
      'musicUrl': musicUrl,
      'collectedAt': FieldValue.serverTimestamp(),
    });
  }
}
