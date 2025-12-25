import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> saveSticker({
  required String uid,
  required String stickerId,
  required String imageUrl,
  required String label,
  required String musicUrl,
}) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('stickers')
      .doc(stickerId)
      .set({
    'imageUrl': imageUrl,
    'label': label,
    'musicUrl': musicUrl,
    'collectedAt': FieldValue.serverTimestamp(),
  });


}
