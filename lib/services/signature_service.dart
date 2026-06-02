import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/signature_data.dart';

class SignatureService {
  static final _col = FirebaseFirestore.instance.collection('signatures');

  static Stream<Map<String, SignatureData>> stream() {
    return _col.snapshots().map((snap) {
      final map = <String, SignatureData>{};
      for (final doc in snap.docs) {
        map[doc.id] = SignatureData.fromJson(doc.data());
      }
      return map;
    });
  }

  static Future<void> add(String id, SignatureData signature) async {
    await _col.doc(id).set(signature.toJson());
  }

  static Future<void> update(String id, SignatureData signature) async {
    await _col.doc(id).set(signature.toJson());
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
