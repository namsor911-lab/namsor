// firebase_service.dart
// ==================== FIREBASE SHARED SERVICE ====================
// ໄຟລ໌ນີ້ຈັດການການ sync ຂໍ້ມູນ Firestore ທັງໝົດ
// ທຸກ user ທີ່ login ຈະເຫັນຂໍ້ມູນດຽວກັນ real-time

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import 'package:accounting/models/transaction.dart';
import 'package:accounting/models/signature_data.dart';
import 'package:accounting/models/shopping_item.dart';
import 'package:accounting/models/plan_item.dart';
import 'package:accounting/models/tax_record.dart';
import 'package:accounting/models/vat_record.dart';
import 'package:accounting/models/profit_tax_record.dart';

// ==================== FIREBASE AUTH SERVICE ====================
class FirebaseAuthService {
  static final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---- ລົງທະບຽນ ----
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

      // ບັນທຶກ profile ໃນ Firestore
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
      return AuthResult(
        success: false,
        message: _authError(e.code),
      );
    } catch (e) {
      return AuthResult(success: false, message: 'ເກີດຂໍ້ຜິດພາດ ກະລຸນາລອງໃໝ່');
    }
  }

  // ---- ເຂົ້າສູ່ລະບົບ ----
  static Future<AuthResult> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final doc = await _db
          .collection('users')
          .doc(credential.user!.uid)
          .get();
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
    } catch (e) {
      return AuthResult(success: false, message: 'ເກີດຂໍ້ຜິດພາດ ກະລຸນາລອງໃໝ່');
    }
  }

  // ---- ອອກຈາກລະບົບ ----
  static Future<void> logout() async {
    await _auth.signOut();
  }

  // ---- ດຶງ session ປັດຈຸບັນ ----
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

  // ---- ດຶງ users ທັງໝົດ ----
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

  // ---- Stream ສຳລັບ auth state changes ----
  static Stream<fb_auth.User?> get authStateChanges =>
      _auth.authStateChanges();

  static String _authError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'ອີເມວນີ້ຖືກໃຊ້ງານແລ້ວ';
      case 'invalid-email':
        return 'ຮູບແບບອີເມວບໍ່ຖືກຕ້ອງ';
      case 'weak-password':
        return 'ລະຫັດຜ່ານຕ້ອງມີຢ່າງໜ້ອຍ 6 ຕົວອັກສອນ';
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

// ---- Auth Result ----
class AuthResult {
  final bool success;
  final String message;
  final String? uid;
  final String? email;
  final String? name;

  AuthResult({
    required this.success,
    required this.message,
    this.uid,
    this.email,
    this.name,
  });
}

// ==================== FIRESTORE: TRANSACTIONS ==================
class TransactionService {
  static final _col = FirebaseFirestore.instance.collection('transactions');

  // Stream real-time
  static Stream<List<Transaction>> stream() {
    return _col.orderBy('date').snapshots().map(
      (snap) =>
          snap.docs.map((d) => Transaction.fromJson(_fix(d))).toList(),
    );
  }

  static Future<void> add(Transaction t) async {
    await _col.doc(t.id).set(t.toJson());
  }

  static Future<void> update(Transaction t) async {
    await _col.doc(t.id).set(t.toJson());
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  static Future<void> deleteAll() async {
    final snap = await _col.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  static Map<String, dynamic> _fix(DocumentSnapshot d) {
    final data = d.data() as Map<String, dynamic>;
    // Firestore Timestamp → ISO string
    if (data['date'] is Timestamp) {
      data['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
    }
    data['id'] = d.id;
    return data;
  }
}

// ==================== FIRESTORE: SIGNATURES ====================
class SignatureService {
  static final _doc = FirebaseFirestore.instance
      .collection('app_data')
      .doc('signatures');

  static Stream<Map<String, SignatureData>> stream() {
    return _doc.snapshots().map((snap) {
      if (!snap.exists) return {};
      final raw = snap.data() as Map<String, dynamic>;
      return raw.map(
        (k, v) => MapEntry(k, SignatureData.fromJson(v as Map<String, dynamic>)),
      );
    });
  }

  static Future<void> update(String role, SignatureData data) async {
    await _doc.set({role: data.toJson()}, SetOptions(merge: true));
  }

  static Future<void> delete(String role) async {
    await _doc.update({role: FieldValue.delete()});
  }

  static Future<void> deleteAll() async {
    await _doc.delete();
  }
}

// ==================== FIRESTORE: SHOPPING ITEMS ====================
class ShoppingItemService {
  static final _col = FirebaseFirestore.instance.collection('shopping_items');

  static Stream<List<ShoppingItem>> stream() {
    return _col.orderBy('date', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        if (data['date'] is Timestamp) {
          data['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
        }
        data['id'] = d.id;
        return ShoppingItem.fromJson(data);
      }).toList(),
    );
  }

  static Future<void> add(ShoppingItem item) async {
    await _col.doc(item.id).set(item.toJson());
  }

  static Future<void> update(ShoppingItem item) async {
    await _col.doc(item.id).set(item.toJson());
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}

// ==================== FIRESTORE: SHOPPING PLAN ====================
class PlanItemService {
  static final _col = FirebaseFirestore.instance.collection('shopping_plan');

  static Stream<List<PlanItem>> stream() {
    return _col.snapshots().map(
      (snap) => snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return PlanItem.fromJson(data);
      }).toList(),
    );
  }

  static Future<void> add(PlanItem item) async {
    await _col.doc(item.id).set(item.toJson());
  }

  static Future<void> update(PlanItem item) async {
    await _col.doc(item.id).set(item.toJson());
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}

// ==================== FIRESTORE: TAX RECORDS ====================
class TaxRecordService {
  static final _empCol = FirebaseFirestore.instance.collection('tax_employees');
  static final _vatCol = FirebaseFirestore.instance.collection('tax_vat');
  static final _profitCol = FirebaseFirestore.instance
      .collection('tax_profit');

  // ---- Employee tax ----
  static Stream<List<TaxRecord>> employeesStream() {
    return _empCol.snapshots().map(
      (snap) => snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return TaxRecord.fromJson(data);
      }).toList(),
    );
  }

  static Future<void> addEmployee(TaxRecord r) async {
    await _empCol.doc(r.id).set(r.toJson());
  }

  static Future<void> updateEmployee(TaxRecord r) async {
    await _empCol.doc(r.id).set(r.toJson());
  }

  static Future<void> deleteEmployee(String id) async {
    await _empCol.doc(id).delete();
  }

  // ---- VAT ----
  static Stream<List<VatRecord>> vatStream() {
    return _vatCol.snapshots().map(
      (snap) => snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return VatRecord.fromJson(data);
      }).toList(),
    );
  }

  static Future<void> addVat(VatRecord r) async {
    await _vatCol.doc(r.id).set(r.toJson());
  }

  static Future<void> deleteVat(String id) async {
    await _vatCol.doc(id).delete();
  }

  // ---- Profit tax ----
  static Stream<List<ProfitTaxRecord>> profitStream() {
    return _profitCol.snapshots().map(
      (snap) => snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return ProfitTaxRecord.fromJson(data);
      }).toList(),
    );
  }

  static Future<void> addProfit(ProfitTaxRecord r) async {
    await _profitCol.doc(r.id).set(r.toJson());
  }

  static Future<void> deleteProfit(String id) async {
    await _profitCol.doc(id).delete();
  }
}