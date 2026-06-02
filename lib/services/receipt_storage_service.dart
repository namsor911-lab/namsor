import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class ReceiptStorageService {
  static final _storage = FirebaseStorage.instance;

  static Future<String?> uploadReceipt(String folder, Uint8List bytes, String filename) async {
    try {
      final ref = _storage.ref().child(folder).child(filename);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteUrl(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // ignore
    }
  }
}
