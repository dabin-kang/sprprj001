import '../models/sticker_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StickerRepository {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<void> add(StickerModel sticker) async {
    final uid = _auth.currentUser!.uid;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('stickers')
        .doc(sticker.id)
        .set(sticker.toJson());
  }

  static Future<List<StickerModel>> getAll() async {
    final uid = _auth.currentUser!.uid;

    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('stickers')
        .get();

    return snap.docs
        .map((e) => StickerModel.fromJson(e.data()))
        .toList();
  }
}
