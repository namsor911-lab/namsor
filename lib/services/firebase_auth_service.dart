import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import '../models/auth_result.dart';

class FirebaseAuthService {
  static final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<AuthResult> register(
    String email,
    String password,
    String name,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());

      await _db.collection('users').doc(credential.user!.uid).set({
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return AuthResult(
        success: true,
        message: 'ລົງທະບຽນສຳເລັດ',
        uid: credential.user!.uid,
        email: email.trim().toLowerCase(),
        name: name.trim(),
      );
    } on fb_auth.FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _authError(e.code));
    } catch (_) {
      return AuthResult(success: false, message: 'ເກີດຂໍ້ຜິດພາດ ກະລຸນາລອງໃໝ່');
    }
  }

  static Future<AuthResult> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final doc = await _db.collection('users').doc(credential.user!.uid).get();
      final name =
          doc.data()?['name'] as String? ??
          credential.user?.displayName ??
          email;

      return AuthResult(
        success: true,
        message: 'ເຂົ້າສູ່ລະບົບສຳເລັດ',
        uid: credential.user!.uid,
        email: email.trim().toLowerCase(),
        name: name,
      );
    } on fb_auth.FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _authError(e.code));
    } catch (_) {
      return AuthResult(success: false, message: 'ເກີດຂໍ້ຜິດພາດ ກະລຸນາລອງໃໝ່');
    }
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  static AuthResult? getCurrentSession() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AuthResult(
      success: true,
      message: '',
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? user.email ?? '',
    );
  }

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snap = await _db.collection('users').get();
      return snap.docs.map((d) {
        final data = d.data();
        return {
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'createdAt': (data['createdAt'] as Timestamp?)
              ?.toDate()
              .toIso8601String(),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Stream<fb_auth.User?> get authStateChanges =>
      _auth.authStateChanges();

  static String _authError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'ອີເມວນີ້ຖືກໃຊ້ງານແລ້ວ';
      case 'invalid-email':
        return 'ຮູບແບບອີເມວບໍ່ຖືກຕ້ອງ';
      case 'weak-password':
        return 'ລະຫັດຜ່ານຕ້ອງມີຢ່າງນ້ອຍ 6 ຕົວອັກສອນ';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'ອີເມວ ຫຼື ລະຫັດຜ່ານບໍ່ຖືກຕ້ອງ';
      case 'too-many-requests':
        return 'ເຂົ້າຜິດຫຼາຍຄັ້ງ ກະລຸນາລໍຖ້າ';
      case 'user-disabled':
        return 'ບັນຊີນີ້ຖືກລ໋ອກ';
      default:
        return 'ເກີດຂໍ້ຜິດພາດ ($code) ກະລຸນາລອງໃໝ່';
    }
  }
}
