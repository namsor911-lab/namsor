// main.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import 'firebase_options.dart';
import 'env_config.dart';

// ==================== FIREBASE SERVICE CLASSES ====================
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

class TransactionService {
  static final _col = FirebaseFirestore.instance.collection('transactions');

  static Stream<List<Transaction>> stream() {
    return _col.orderBy('date').snapshots().map(
          (snap) => snap.docs.map((d) => Transaction.fromJson(_fix(d))).toList(),
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
    if (data['date'] is Timestamp) {
      data['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
    }
    data['id'] = d.id;
    return data;
  }
}

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


// ==================== RECEIPT STORAGE SERVICE ====================
class ReceiptStorageService {
  static final fb_storage.FirebaseStorage _storage = fb_storage.FirebaseStorage.instance;

  static Future<String?> uploadReceipt(String uid, List<int> bytes, String fileName) async {
    try {
      final ref = _storage.ref().child('receipts/$uid/${DateTime.now().millisecondsSinceEpoch}_$fileName');
      final task = await ref.putData(
        Uint8List.fromList(bytes),
        fb_storage.SettableMetadata(contentType: 'image/jpeg'),
      );
      return await task.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteReceipt(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }
}

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


class BudgetPlanItemService {
  static final _col = FirebaseFirestore.instance.collection('budget_plan_items');

  static Stream<List<BudgetPlanItem>> streamByMonth(String monthKey) {
    return _col
        .where('monthKey', isEqualTo: monthKey)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return BudgetPlanItem.fromJson(data);
            }).toList());
  }

  static Future<void> add(BudgetPlanItem item) async {
    await _col.doc(item.id).set(item.toJson());
  }

  static Future<void> update(BudgetPlanItem item) async {
    await _col.doc(item.id).set(item.toJson());
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}

class TaxRecordService {
  static final _empCol = FirebaseFirestore.instance.collection('tax_employees');
  static final _vatCol = FirebaseFirestore.instance.collection('tax_vat');
  static final _profitCol = FirebaseFirestore.instance.collection('tax_profit');

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

// ==================== SHOPPING MODELS & HELPERS ====================
final List<PlanItem> globalPlanItems = [];

Widget buildReceiptImage(String path, Widget placeholder) {
  return Image.network(
    path,
    width: 250,
    height: 350,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => placeholder,
  );
}

class ShoppingItem {
  final String id;
  DateTime date;
  String itemName;
  double quantity;
  double unitPrice;
  String unit;
  String note;
  List<String> receipts;

  double get totalPrice => quantity * unitPrice;

  ShoppingItem({
    required this.id,
    required this.date,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.unit,
    this.note = '',
    this.receipts = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'itemName': itemName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'unit': unit,
        'note': note,
        'receipts': receipts,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        itemName: json['itemName'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        unit: json['unit'] as String,
        note: json['note'] as String? ?? '',
        receipts: List<String>.from((json['receipts'] as List?)?.cast<String>() ?? []),
      );
}

class PlanItem {
  final String id;
  String itemName;
  double quantity;
  String unit;
  String note;

  PlanItem({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemName': itemName,
        'quantity': quantity,
        'unit': unit,
        'note': note,
      };

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
        id: json['id'] as String,
        itemName: json['itemName'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String,
        note: json['note'] as String? ?? '',
      );
}


// ==================== BUDGET PLAN MODEL ====================
class BudgetPlanItem {
  final String id;
  String itemName;
  String category;
  double plannedAmount;
  double actualAmount;
  String status;
  String note;
  String monthKey; // "YYYY_MM"
  List<String> receipts;
  String? sigApprover;
  String? sigManager;
  String? sigChief;
  String? sigFinance;

  BudgetPlanItem({
    required this.id,
    required this.itemName,
    required this.category,
    required this.plannedAmount,
    this.actualAmount = 0,
    this.status = 'ວາງແຜນ',
    this.note = '',
    required this.monthKey,
    this.receipts = const [],
    this.sigApprover,
    this.sigManager,
    this.sigChief,
    this.sigFinance,
  });

  double get remaining => plannedAmount - actualAmount;
  double get progressPct => plannedAmount > 0
      ? (actualAmount / plannedAmount * 100).clamp(0, 100)
      : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemName': itemName,
        'category': category,
        'plannedAmount': plannedAmount,
        'actualAmount': actualAmount,
        'status': status,
        'note': note,
        'monthKey': monthKey,
        'receipts': receipts,
        'sigApprover': sigApprover,
        'sigManager': sigManager,
        'sigChief': sigChief,
        'sigFinance': sigFinance,
      };

  factory BudgetPlanItem.fromJson(Map<String, dynamic> j) => BudgetPlanItem(
        id: j['id'] as String,
        itemName: j['itemName'] as String,
        category: j['category'] as String? ?? 'ອື່ນໆ',
        plannedAmount: (j['plannedAmount'] as num).toDouble(),
        actualAmount: (j['actualAmount'] as num? ?? 0).toDouble(),
        status: j['status'] as String? ?? 'ວາງແຜນ',
        note: j['note'] as String? ?? '',
        monthKey: j['monthKey'] as String? ?? '',
        receipts: List<String>.from((j['receipts'] as List?)?.cast<String>() ?? []),
        sigApprover: j['sigApprover'] as String?,
        sigManager: j['sigManager'] as String?,
        sigChief: j['sigChief'] as String?,
        sigFinance: j['sigFinance'] as String?,
      );
}

class TaxRecord {
  final String id;
  String employeeName;
  String position;
  double grossSalary;
  double taxRate;

  double get taxAmount => grossSalary * (taxRate / 100);
  double get netSalary => grossSalary - taxAmount;

  TaxRecord({
    required this.id,
    required this.employeeName,
    required this.position,
    required this.grossSalary,
    required this.taxRate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeName': employeeName,
        'position': position,
        'grossSalary': grossSalary,
        'taxRate': taxRate,
      };

  factory TaxRecord.fromJson(Map<String, dynamic> j) => TaxRecord(
        id: j['id'] as String,
        employeeName: j['employeeName'] as String,
        position: j['position'] as String,
        grossSalary: (j['grossSalary'] as num).toDouble(),
        taxRate: (j['taxRate'] as num).toDouble(),
      );
}

class VatRecord {
  final String id;
  String invoiceNo;
  String detail;
  double amountBeforeVat;
  double vatRate;

  double get vatAmount => amountBeforeVat * (vatRate / 100);
  double get totalAmount => amountBeforeVat + vatAmount;

  VatRecord({
    required this.id,
    required this.invoiceNo,
    required this.detail,
    required this.amountBeforeVat,
    this.vatRate = 10.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceNo': invoiceNo,
        'detail': detail,
        'amountBeforeVat': amountBeforeVat,
        'vatRate': vatRate,
      };

  factory VatRecord.fromJson(Map<String, dynamic> j) => VatRecord(
        id: j['id'] as String,
        invoiceNo: j['invoiceNo'] as String,
        detail: j['detail'] as String,
        amountBeforeVat: (j['amountBeforeVat'] as num).toDouble(),
        vatRate: (j['vatRate'] as num? ?? 10.0).toDouble(),
      );
}

class ProfitTaxRecord {
  final String id;
  String periodTitle;
  double totalRevenue;
  double totalExpense;
  double taxRate;

  double get netProfit => totalRevenue - totalExpense;
  double get taxAmount => netProfit > 0 ? netProfit * (taxRate / 100) : 0.0;

  ProfitTaxRecord({
    required this.id,
    required this.periodTitle,
    required this.totalRevenue,
    required this.totalExpense,
    this.taxRate = 20.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'periodTitle': periodTitle,
        'totalRevenue': totalRevenue,
        'totalExpense': totalExpense,
        'taxRate': taxRate,
      };

  factory ProfitTaxRecord.fromJson(Map<String, dynamic> j) => ProfitTaxRecord(
        id: j['id'] as String,
        periodTitle: j['periodTitle'] as String,
        totalRevenue: (j['totalRevenue'] as num).toDouble(),
        totalExpense: (j['totalExpense'] as num).toDouble(),
        taxRate: (j['taxRate'] as num? ?? 20.0).toDouble(),
      );
}

class TaxStorageService {
  static const String _empKey = 'tax_records_v1';
  static const String _vatKey = 'vat_records_v1';
  static const String _profitKey = 'profit_records_v1';

  static List<TaxRecord> loadEmployees() {
    try {
      final json = html.window.localStorage[_empKey];
      if (json == null) return [];
      return (jsonDecode(json) as List)
          .map((e) => TaxRecord.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static void saveEmployees(List<TaxRecord> r) =>
      html.window.localStorage[_empKey] = jsonEncode(r.map((e) => e.toJson()).toList());

  static List<VatRecord> loadVat() {
    try {
      final json = html.window.localStorage[_vatKey];
      if (json == null) return [];
      return (jsonDecode(json) as List).map((e) => VatRecord.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static void saveVat(List<VatRecord> r) =>
      html.window.localStorage[_vatKey] = jsonEncode(r.map((e) => e.toJson()).toList());

  static List<ProfitTaxRecord> loadProfit() {
    try {
      final json = html.window.localStorage[_profitKey];
      if (json == null) return [];
      return (jsonDecode(json) as List)
          .map((e) => ProfitTaxRecord.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static void saveProfit(List<ProfitTaxRecord> r) =>
      html.window.localStorage[_profitKey] = jsonEncode(r.map((e) => e.toJson()).toList());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'namsor hydropower — ເຂື່ອນໄຟຟ້ານ້ຳຊໍ້',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF3FB950),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        fontFamily: 'IBM Plex Sans Thai',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3FB950),
          surface: Color(0xFF161B22),
          onSurface: Color(0xFFE6EDF3),
          secondary: Color(0xFFF85149),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1C2128),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF30363D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF58A6FF)),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// ==================== AUTH PAGE ====================
// ຍອດເກັບໜ້າ login / register
class AuthPage extends StatefulWidget {
  final Function(AuthResult) onAuthenticated;

  const AuthPage({super.key, required this.onAuthenticated});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;

  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _loginObscure = true;

  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();
  bool _regObscure = true;
  bool _regConfirmObscure = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _errorMessage = null);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmCtrl.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await FirebaseAuthService.login(
      _loginEmailCtrl.text,
      _loginPasswordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      widget.onAuthenticated(result);
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  void _handleRegister() async {
    if (_regPasswordCtrl.text != _regConfirmCtrl.text) {
      setState(() => _errorMessage = 'ລະຫັດຜ່ານທັງສອງຊ່ອງບໍ່ກົງກັນ');
      return;
    }
    if (_regPasswordCtrl.text.length < 6) {
      setState(() => _errorMessage = 'ລະຫັດຜ່ານຕ້ອງມີຢ່າງນ້ອຍ 6 ຕົວອັກສອນ');
      return;
    }
    if (_regNameCtrl.text.trim().length < 2) {
      setState(() => _errorMessage = 'ກະລຸນາໃສ່ຊື່ຢ່າງນ້ອຍ 2 ຕົວອັກສອນ');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await FirebaseAuthService.register(
      _regEmailCtrl.text,
      _regPasswordCtrl.text,
      _regNameCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      widget.onAuthenticated(result);
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(),
                const SizedBox(height: 40),
                _buildCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF238636), Color(0xFF3FB950)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3FB950).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Text('⚡', style: TextStyle(fontSize: 32)),
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'ນ້ຳ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE6EDF3),
                ),
              ),
              TextSpan(
                text: 'ຊໍ້',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3FB950),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'ເຂື່ອນໄຟຟ້ານ້ຳຊໍ້',
          style: TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border.all(color: const Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF3FB950),
              indicatorWeight: 2,
              labelColor: const Color(0xFF3FB950),
              unselectedLabelColor: const Color(0xFF8B949E),
              tabs: const [
                Tab(text: 'ເຂົ້າສູ່ລະບົບ'),
                Tab(text: 'ລົງທະບຽນ'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (_errorMessage != null) ...[
                  _buildErrorBanner(_errorMessage!),
                  const SizedBox(height: 16),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    height: _tabController.index == 0 ? 220 : 340,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLoginForm(),
                        _buildRegisterForm(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4D2A2A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF85149).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFF85149), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFFF85149)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _loginEmailCtrl,
          decoration: const InputDecoration(
            labelText: 'ອີເມວ',
            prefixIcon: Icon(Icons.email_outlined, size: 16),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _loginPasswordCtrl,
          obscureText: _loginObscure,
          decoration: InputDecoration(
            labelText: 'ລະຫັດຜ່ານ',
            prefixIcon: const Icon(Icons.lock_outline, size: 16),
            suffixIcon: IconButton(
              icon: Icon(
                _loginObscure ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              onPressed: () => setState(() => _loginObscure = !_loginObscure),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3FB950),
            minimumSize: const Size.fromHeight(48),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('ເຂົ້າສູ່ລະບົບ'),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _regNameCtrl,
          decoration: const InputDecoration(
            labelText: 'ຊື່',
            prefixIcon: Icon(Icons.person_outline, size: 16),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regEmailCtrl,
          decoration: const InputDecoration(
            labelText: 'ອີເມວ',
            prefixIcon: Icon(Icons.email_outlined, size: 16),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regPasswordCtrl,
          obscureText: _regObscure,
          decoration: InputDecoration(
            labelText: 'ລະຫັດຜ່ານ',
            prefixIcon: const Icon(Icons.lock_outline, size: 16),
            suffixIcon: IconButton(
              icon: Icon(
                _regObscure ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              onPressed: () => setState(() => _regObscure = !_regObscure),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regConfirmCtrl,
          obscureText: _regConfirmObscure,
          decoration: InputDecoration(
            labelText: 'ຢືນຢັນລະຫັດຜ່ານ',
            prefixIcon: const Icon(Icons.lock_outline, size: 16),
            suffixIcon: IconButton(
              icon: Icon(
                _regConfirmObscure ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              onPressed: () => setState(() => _regConfirmObscure = !_regConfirmObscure),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF238636),
            minimumSize: const Size.fromHeight(48),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('ລົງທະບຽນ'),
        ),
      ],
    );
  }
}

// ==================== AUTH WRAPPER ====================
// ໃຊ້ StreamBuilder ເພື່ອ listen Firebase auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D1117),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF3FB950)),
            ),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return AuthPage(
            onAuthenticated: (_) {},
          );
        }
        return MainScreen(
          currentUser: AuthResult(
            success: true,
            message: '',
            uid: user.uid,
            email: user.email ?? '',
            name: user.displayName ?? user.email ?? '',
          ),
          onLogout: () async {
            await FirebaseAuthService.logout();
          },
        );
      },
    );
  }
}

// ==================== DATA MODELS ====================
class Transaction {
  final String id;
  final DateTime date;
  final String desc;
  final double income;
  final double expense;
  final String note;
  double balance;

  Transaction({
    required this.id,
    required this.date,
    required this.desc,
    required this.income,
    required this.expense,
    this.note = '',
    this.balance = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'desc': desc,
    'income': income,
    'expense': expense,
    'note': note,
    'balance': balance,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    desc: json['desc'] as String,
    income: (json['income'] as num?)?.toDouble() ?? 0.0,
    expense: (json['expense'] as num?)?.toDouble() ?? 0.0,
    note: json['note'] as String? ?? '',
    balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
  );
}

class SignatureData {
  final String? dataUrl;
  final bool approved;
  final String? ts;
  final String? name;

  SignatureData({this.dataUrl, this.approved = false, this.ts, this.name});

  Map<String, dynamic> toJson() => {
    'dataUrl': dataUrl,
    'approved': approved,
    'ts': ts,
    'name': name,
  };

  factory SignatureData.fromJson(Map<String, dynamic> json) => SignatureData(
    dataUrl: json['dataUrl'] as String?,
    approved: json['approved'] as bool? ?? false,
    ts: json['ts'] as String?,
    name: json['name'] as String?,
  );
}

// ==================== CONSTANTS ====================
const List<String> months = [
  'ມັງກອນ', 'ກຸມພາ', 'ມີນາ', 'ເມສາ', 'ພຶດສະພາ', 'ມິຖຸນາ',
  'ກໍລະກົດ', 'ສິງຫາ', 'ກັນຍາ', 'ຕຸລາ', 'ພະຈິກ', 'ທັນວາ',
];

const List<String> monthsShort = [
  'ມ.ກ', 'ກ.ພ', 'ມ.ນ', 'ມ.ສ', 'ພ.ສ', 'ມ.ຖ',
  'ກ.ກ', 'ສ.ຫ', 'ກ.ຍ', 'ຕ.ລ', 'ພ.ຈ', 'ທ.ວ',
];

const List<Map<String, dynamic>> quarters = [
  {'name': 'Q1', 'months': [1, 2, 3], 'color': Color(0xFF58A6FF)},
  {'name': 'Q2', 'months': [4, 5, 6], 'color': Color(0xFF3FB950)},
  {'name': 'Q3', 'months': [7, 8, 9], 'color': Color(0xFFD29922)},
  {'name': 'Q4', 'months': [10, 11, 12], 'color': Color(0xFFBC8CFF)},
];

const List<String> signatureRoles = [
  'ຜູ້ອຳນວຍການ',
  'ຫົວໜ້າເຂື່ອນ',
  'ບັນຊີ-ການເງິນ',
  'ຜູ້ສະຫຼຸບ',
];

const List<String> budgetSignatureRoles = [
  'ຜູ້ຮັບຜິດຊອບ',
  'ຜູ້ອຳນວຍການ',
  'ຫົວໜ້າເຂື່ອນ',
  'ຜູ້ອະນຸມັດ',
];

const List<String> budgetCategories = [
  'ອຸປະກອນ',
  'ວັດສະດຸ',
  'ເຄື່ອງຈັກ',
  'ອາຫານ',
  'ນ້ຳມັນ',
  'ອື່ນໆ',
];

class _MonthSummary {
  final int month;
  final double total;

  _MonthSummary({required this.month, required this.total});
}

// ==================== SHOPPING LIST PAGE ====================
class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final List<ShoppingItem> _items = [];
  String _searchQuery = '';

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final List<String> months = [
    'ມັງກອນ', 'ກຸມພາ', 'ມີນາ', 'ເມສາ', 'ພຶດສະພາ', 'ມິຖຸນາ',
    'ກໍລະກົດ', 'ສິງຫາ', 'ກັນຍາ', 'ຕຸລາ', 'ພະຈິກ', 'ທັນວາ',
  ];

  String _formatMoney(double amount) {
    final formatter = NumberFormat('#,###', 'lo');
    return '${formatter.format(amount)} ₭';
  }

  List<_MonthSummary> _getMonthlyTotals() {
    return List.generate(12, (i) {
      final m = i + 1;
      final total = _items
          .where((item) => item.date.year == _selectedYear && item.date.month == m)
          .fold(0.0, (s, item) => s + item.totalPrice);
      return _MonthSummary(month: m, total: total);
    });
  }

  List<ShoppingItem> _getTopItems(List<ShoppingItem> filtered) {
    final sorted = [...filtered]..sort((a, b) => b.totalPrice.compareTo(a.totalPrice));
    return sorted.take(5).toList();
  }

  double _getGrandTotal(List<ShoppingItem> filtered) =>
      filtered.fold(0.0, (s, item) => s + item.totalPrice);

  @override
  Widget build(BuildContext context) {
    final filteredItems = _items.where((item) {
      final matchesSearch =
          item.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.note.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesDate =
          item.date.month == _selectedMonth && item.date.year == _selectedYear;
      return matchesSearch && matchesDate;
    }).toList();

    final grandTotal = _getGrandTotal(filteredItems);
    final topItems = _getTopItems(filteredItems);
    final monthlyTotals = _getMonthlyTotals();
    final maxMonthly = monthlyTotals.fold(0.0, (s, d) => d.total > s ? d.total : s);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        final leftPanel = _buildLeftPanel(filteredItems);
        final rightPanel = _buildRightPanel(
          filteredItems: filteredItems,
          grandTotal: grandTotal,
          topItems: topItems,
          monthlyTotals: monthlyTotals,
          maxMonthly: maxMonthly,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: leftPanel),
              const SizedBox(width: 16),
              SizedBox(width: 320, child: rightPanel),
            ],
          );
        } else {
          return Column(
            children: [
              leftPanel,
              const SizedBox(height: 16),
              rightPanel,
            ],
          );
        }
      },
    );
  }

  Widget _buildLeftPanel(List<ShoppingItem> filteredItems) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              border: Border.all(color: const Color(0xFF30363D)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1F6FEB), Color(0xFF58A6FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('🛒', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ບັນຊີລາຍການຊື້ເຄື່ອງ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE6EDF3),
                            ),
                          ),
                          Text(
                            'ອຸປະກອນ & ອາໄຫຼ່ — ເຂື່ອນໄຟຟ້ານ້ຳຊໍ້',
                            style: TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ShoppingPlanPage()),
                        );
                      },
                      icon: const Icon(Icons.assignment_outlined, size: 15),
                      label: const Text('ແຜນຊື້ເຄື່ອງ', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F4E79),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showShoppingDialog(),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('ເພີ່ມລາຍການ', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF238636),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: const InputDecoration(
                    hintText: 'ຄົ້ນຫາ...',
                    prefixIcon: Icon(Icons.search, size: 14),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        value: _selectedMonth,
                        dropdownColor: const Color(0xFF1C2128),
                        underline: const SizedBox(),
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(value: i + 1, child: Text(months[i])),
                        ),
                        onChanged: (value) => setState(() => _selectedMonth = value!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<int>(
                        value: _selectedYear,
                        dropdownColor: const Color(0xFF1C2128),
                        underline: const SizedBox(),
                        items: [
                          DateTime.now().year - 3,
                          DateTime.now().year - 2,
                          DateTime.now().year - 1,
                          DateTime.now().year,
                          DateTime.now().year + 1,
                        ].map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                        onChanged: (value) => setState(() => _selectedYear = value!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildItemsSection(filteredItems),
        ],
      ),
    );
  }

  Widget _buildItemsSection(List<ShoppingItem> filteredItems) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            border: Border.all(color: const Color(0xFF30363D)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ລາຍການຊື້',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (filteredItems.isEmpty)
                const Text('ບໍ່ມີລາຍການຕາມຕົວເລືອກ', style: TextStyle(color: Color(0xFF8B949E)))
              else
                Column(
                  children: filteredItems
                      .map((item) => _ShoppingItemTile(
                            item: item,
                            onEdit: () => _showShoppingDialog(item: item),
                            onDelete: () => _deleteItem(item.id),
                            onViewReceipts: () => _showReceiptViewer(item.receipts),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel({
    required List<ShoppingItem> filteredItems,
    required double grandTotal,
    required List<ShoppingItem> topItems,
    required List<_MonthSummary> monthlyTotals,
    required double maxMonthly,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              border: Border.all(color: const Color(0xFF30363D)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ສະຫຼຸບ',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _SummaryItem(
                  label: 'ລາຍການທັງໝົດ',
                  value: '${filteredItems.length}',
                  color: const Color(0xFF58A6FF),
                ),
                const SizedBox(height: 8),
                _SummaryItem(
                  label: 'ລາຍຮັບລວມ',
                  value: _formatMoney(grandTotal),
                  color: const Color(0xFF3FB950),
                ),
                const SizedBox(height: 8),
                _SummaryItem(
                  label: 'ລາຍການທ່າງສຸດ',
                  value: '${topItems.length} Top',
                  color: const Color(0xFF8B949E),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              border: Border.all(color: const Color(0xFF30363D)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ລາຍການຂ່ອຍຫລາຍ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...topItems.map((item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.itemName, style: const TextStyle(fontSize: 13, color: Color(0xFFE6EDF3))),
                      trailing: Text(_formatMoney(item.totalPrice), style: const TextStyle(color: Color(0xFF3FB950))),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildMonthlyGraph(monthlyTotals, maxMonthly),
        ],
      ),
    );
  }

  Widget _buildMonthlyGraph(List<_MonthSummary> monthlyTotals, double maxMonthly) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border.all(color: const Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ກຣາຟລາຍການ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: monthlyTotals.map((summary) {
                final height = maxMonthly > 0 ? summary.total / maxMonthly * 120 : 0;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 16,
                        height: height.clamp(4.0, 120.0) as double,
                        decoration: BoxDecoration(
                          color: const Color(0xFF58A6FF),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(months[summary.month - 1].substring(0, 2), style: const TextStyle(fontSize: 10, color: Color(0xFF8B949E))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiptViewer(List<String> receipts) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ຮູບພາບໃບບິນ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF8B949E), size: 18),
                onPressed: () => Navigator.pop(ctx),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: receipts.map((path) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF30363D)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: buildReceiptImage(path, _buildErrorPlaceholder()),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: 250,
      height: 350,
      color: const Color(0xFF0D1117),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, color: Color(0xFF484F58), size: 40),
          SizedBox(height: 8),
          Text('ບໍ່ສາມາດໂຫຼດຮູບໄດ້', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
        ],
      ),
    );
  }

  void _showShoppingDialog({ShoppingItem? item}) async {
    final isEdit = item != null;
    DateTime selectedDate = item?.date ?? DateTime.now();

    final itemController = TextEditingController(text: item?.itemName ?? '');
    final qtyController =
        TextEditingController(text: item != null ? item.quantity.toString() : '');
    final priceController =
        TextEditingController(text: item != null ? item.unitPrice.toString() : '');
    final unitController = TextEditingController(text: item?.unit ?? '');
    final noteController = TextEditingController(text: item?.note ?? '');

    List<String> selectedReceipts = item?.receipts.toList() ?? [];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double calculateRealtimeTotal() {
              final qty = double.tryParse(qtyController.text) ?? 0;
              final price = double.tryParse(priceController.text) ?? 0;
              return qty * price;
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF161B22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFF30363D)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isEdit ? const Color(0xFF1F4E79) : const Color(0xFF1A4D2E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_outlined : Icons.add_shopping_cart,
                      size: 16,
                      color: isEdit
                          ? const Color(0xFF58A6FF)
                          : const Color(0xFF3FB950),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? 'ແກ້ຄວ່າງ' : 'ເພີ່ມລາຍການ',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3)),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) setDialogState(() => selectedDate = date);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF30363D)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF8B949E)),
                              const SizedBox(width: 8),
                              const Text('ວັນທີ: ', style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
                              Text(
                                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              const Icon(Icons.chevron_right, size: 16, color: Color(0xFF484F58)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: itemController,
                        decoration: const InputDecoration(
                          labelText: 'ຊື່ອຸປະກອນ / ລາຍການ',
                          prefixIcon: Icon(Icons.inventory_2_outlined, size: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: qtyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'ຈຳນວນ'),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: unitController,
                              decoration: const InputDecoration(labelText: 'ຫົວໜ່ວຍ (ອັນ, ຊຸດ...)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ລາຄາຊື້ (₭ ຕໍ່ 1 ຫົວໜ່ວຍ)',
                          prefixIcon: Icon(Icons.monetization_on_outlined, size: 16),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: 'ໝາຍເຫດ (ຖ້າມີ)',
                          prefixIcon: Icon(Icons.notes_outlined, size: 16),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final ImagePicker picker = ImagePicker();
                            final List<XFile> images = await picker.pickMultiImage();
                            if (images.isNotEmpty) {
                              setDialogState(() {
                                selectedReceipts.addAll(images.map((e) => e.path));
                              });
                            }
                          },
                          icon: const Icon(Icons.add_photo_alternate_outlined, size: 15),
                          label: const Text('ເພີ່ມຮູບໃບບິນ', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF21262D),
                            foregroundColor: const Color(0xFFE6EDF3),
                            side: const BorderSide(color: Color(0xFF30363D)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            elevation: 0,
                          ),
                        ),
                      ),
                      if (selectedReceipts.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: selectedReceipts.asMap().entries.map((entry) {
                              final idx = entry.key;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1C2128),
                                  border: Border.all(color: const Color(0xFF30363D)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.image_outlined, size: 14, color: Color(0xFF58A6FF)),
                                    const SizedBox(width: 6),
                                    Text('ຮູບ ${idx + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          selectedReceipts.removeAt(idx);
                                        });
                                      },
                                      child: const Icon(Icons.close, size: 14, color: Color(0xFFF85149)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1A4D2E).withValues(alpha: 0.5),
                              const Color(0xFF1A4D2E).withValues(alpha: 0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF3FB950).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ຜົນລວມທັງໝົດ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF8B949E),
                                  ),
                                ),
                                Text(
                                  'ຈຳນວນ × ລາຄາ',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                                ),
                              ],
                            ),
                            Text(
                              _formatMoney(calculateRealtimeTotal()),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF3FB950),
                                fontFamily: 'IBM Plex Mono',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ຍົກເລີກ'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () {
                    final name = itemController.text.trim();
                    final qty = double.tryParse(qtyController.text) ?? 0;
                    final price = double.tryParse(priceController.text) ?? 0;
                    final unit = unitController.text.trim();

                    if (name.isEmpty || qty <= 0 || price <= 0 || unit.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ກະລຸນາປ້ອນຂໍ້ມູນໃຫ້ຄົບ ແລະ ຖືກຕ້ອງ')),
                      );
                      return;
                    }

                    setState(() {
                      if (isEdit) {
                        item.date = selectedDate;
                        item.itemName = name;
                        item.quantity = qty;
                        item.unitPrice = price;
                        item.unit = unit;
                        item.note = noteController.text.trim();
                        item.receipts = selectedReceipts;
                      } else {
                        _items.add(ShoppingItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          date: selectedDate,
                          itemName: name,
                          quantity: qty,
                          unitPrice: price,
                          unit: unit,
                          note: noteController.text.trim(),
                          receipts: selectedReceipts,
                        ));
                      }
                    });

                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    isEdit ? 'ບັນທຶກການແກ້ໄຂ' : 'ບັນທຶກລາຍການ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteItem(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF85149), size: 20),
            SizedBox(width: 8),
            Text('ຢືນຢັນການລຶບ'),
          ],
        ),
        content: const Text('ທ່ານຕ້ອງການລຶບລາຍການຊື້ເຄື່ອງນີ້ແທ້ ຫຼື ບໍ່?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ຍົກເລີກ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4D2A2A),
              foregroundColor: const Color(0xFFF85149),
            ),
            onPressed: () {
              setState(() => _items.removeWhere((item) => item.id == id));
              Navigator.pop(ctx);
            },
            child: const Text('ລຶບ'),
          ),
        ],
      ),
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewReceipts;

  const _ShoppingItemTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onViewReceipts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border.all(color: const Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.itemName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.image_outlined, size: 18),
                onPressed: onViewReceipts,
                tooltip: 'ເບິ່ງຮູບໃບບິນ',
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: onEdit,
                tooltip: 'ແກ້ໄຂ',
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 18),
                onPressed: onDelete,
                tooltip: 'ລຶບ',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${item.quantity} ${item.unit}', style: const TextStyle(color: Color(0xFF8B949E))),
              const SizedBox(width: 16),
              Text(_formatMoney(item.totalPrice), style: const TextStyle(color: Color(0xFF3FB950), fontWeight: FontWeight.w600)),
            ],
          ),
          if (item.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.note, style: const TextStyle(color: Color(0xFF8B949E))),
          ],
        ],
      ),
    );
  }

  String _formatMoney(double amount) {
    final formatter = NumberFormat('#,###', 'lo');
    return '${formatter.format(amount)} ₭';
  }
}

class ShoppingPlanPage extends StatefulWidget {
  const ShoppingPlanPage({super.key});

  @override
  State<ShoppingPlanPage> createState() => _ShoppingPlanPageState();
}

class _ShoppingPlanPageState extends State<ShoppingPlanPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredItems = globalPlanItems.where((item) {
      return item.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.note.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('ແຜນຊື້ເຄື່ອງ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE6EDF3))),
        iconTheme: const IconThemeData(color: Color(0xFFE6EDF3)),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF30363D)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                border: Border.all(color: const Color(0xFF30363D)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      style: const TextStyle(fontSize: 13, color: Color(0xFFE6EDF3)),
                      decoration: const InputDecoration(
                        hintText: 'ຄົ້ນຫາລາຍການແຜນຊື້...',
                        hintStyle: TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                        prefixIcon: Icon(Icons.search, size: 14, color: Color(0xFF8B949E)),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showPlanDialog(),
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('ເພີ່ມແຜນຊື້', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                border: Border.all(color: const Color(0xFF30363D)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: filteredItems.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.assignment_outlined, size: 40, color: Color(0xFF484F58)),
                            SizedBox(height: 12),
                            Text(
                              'ຍັງບໍ່ມີລາຍການແຜນຊື້ເຄື່ອງ',
                              style: TextStyle(fontSize: 14, color: Color(0xFF8B949E)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFF21262D))),
                          ),
                          child: Text(
                            'ລວມທັງໝົດ: ${filteredItems.length} ລາຍການ',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 24,
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF0D1117)),
                            headingTextStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8B949E),
                            ),
                            dataTextStyle: const TextStyle(fontSize: 12, color: Color(0xFFE6EDF3)),
                            dividerThickness: 0.5,
                            columns: const [
                              DataColumn(label: Text('ລ/ດ')),
                              DataColumn(label: Text('ລາຍການຊື້')),
                              DataColumn(label: Text('ຈຳນວນ')),
                              DataColumn(label: Text('ຫົວໜ່ວຍ')),
                              DataColumn(label: Text('ໝາຍເຫດ')),
                              DataColumn(label: Text('ຈັດການ')),
                            ],
                            rows: List.generate(filteredItems.length, (index) {
                              final item = filteredItems[index];
                              return DataRow(
                                cells: [
                                  DataCell(Text('${index + 1}', style: const TextStyle(color: Color(0xFF484F58)))),
                                  DataCell(Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w500))),
                                  DataCell(Text(item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2), style: const TextStyle(color: Color(0xFF58A6FF)))),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1C2128),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF30363D)),
                                    ),
                                    child: Text(item.unit, style: const TextStyle(fontSize: 11)),
                                  )),
                                  DataCell(Text(item.note.isEmpty ? '—' : item.note, style: const TextStyle(color: Color(0xFF8B949E)))),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF58A6FF)),
                                        onPressed: () => _showPlanDialog(item: item),
                                        tooltip: 'ແກ້ໄຂ',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFF85149)),
                                        onPressed: () => _deletePlanItem(item.id),
                                        tooltip: 'ລຶບ',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      ),
                                    ],
                                  )),
                                ],
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlanDialog({PlanItem? item}) async {
    final isEdit = item != null;
    final itemController = TextEditingController(text: item?.itemName ?? '');
    final qtyController = TextEditingController(text: item != null ? item.quantity.toString() : '');
    final unitController = TextEditingController(text: item?.unit ?? '');
    final noteController = TextEditingController(text: item?.note ?? '');
    final receipts = <String>[];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isEdit ? const Color(0xFF1F4E79) : const Color(0xFF1A4D2E),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isEdit ? Icons.edit_outlined : Icons.assignment_add,
                  size: 16,
                  color: isEdit ? const Color(0xFF58A6FF) : const Color(0xFF3FB950),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isEdit ? 'ແກ້ໄຂແຜນຊື້' : 'ເພີ່ມແຜນຊື້',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3)),
              ),
            ],
          ),
          content: SizedBox(
            width: 350,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: itemController,
                    style: const TextStyle(color: Color(0xFFE6EDF3)),
                    decoration: const InputDecoration(
                      labelText: 'ລາຍການຊື້',
                      prefixIcon: Icon(Icons.inventory_2_outlined, size: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFFE6EDF3)),
                          decoration: const InputDecoration(labelText: 'ຈຳນວນ'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: unitController,
                          style: const TextStyle(color: Color(0xFFE6EDF3)),
                          decoration: const InputDecoration(labelText: 'ຫົວໜ່ວຍ (ອັນ, ຊຸດ...)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    style: const TextStyle(color: Color(0xFFE6EDF3)),
                    decoration: const InputDecoration(
                      labelText: 'ໝາຍເຫດ',
                      prefixIcon: Icon(Icons.notes_outlined, size: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Receipt upload
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      border: Border.all(color: const Color(0xFF30363D)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: StatefulBuilder(
                      builder: (sCtx, setSub) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('📎 ໃບບິນ', style: TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () async {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                                  if (picked == null) return;
                                  final bytes = await picked.readAsBytes();
                                  final url = await ReceiptStorageService.uploadReceipt('receipts', bytes.toList(), picked.name);
                                  if (url != null) setSub(() => receipts.add(url));
                                },
                                icon: const Icon(Icons.add_photo_alternate_outlined, size: 12),
                                label: const Text('ເພີ່ມ', style: TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(foregroundColor: const Color(0xFF3FB950)),
                              ),
                            ],
                          ),
                          if (receipts.isNotEmpty)
                            Wrap(
                              spacing: 6, runSpacing: 6,
                              children: receipts.asMap().entries.map((e) => Stack(
                                children: [
                                  ClipRRect(borderRadius: BorderRadius.circular(4),
                                      child: Image.network(e.value, width: 48, height: 48, fit: BoxFit.cover,
                                          errorBuilder: (c, er, s) => const Icon(Icons.broken_image))),
                                  Positioned(top: 0, right: 0,
                                    child: GestureDetector(
                                      onTap: () => setSub(() => receipts.removeAt(e.key)),
                                      child: Container(width: 14, height: 14,
                                        decoration: const BoxDecoration(color: Color(0xFFF85149), shape: BoxShape.circle),
                                        child: const Icon(Icons.close, size: 9, color: Colors.white)),
                                    )),
                                ],
                              )).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ຍົກເລີກ'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () {
                final name = itemController.text.trim();
                final qty = double.tryParse(qtyController.text) ?? 0;
                final unit = unitController.text.trim();

                if (name.isEmpty || qty <= 0 || unit.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ກະລຸນາປ້ອນຂໍ້ມູນໃຫ້ຄົບຖ້ວນ')),
                  );
                  return;
                }

                setState(() {
                  if (isEdit) {
                    item.itemName = name;
                    item.quantity = qty;
                    item.unit = unit;
                    item.note = noteController.text.trim();
                  } else {
                    globalPlanItems.add(PlanItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      itemName: name,
                      quantity: qty,
                      unit: unit,
                      note: noteController.text.trim(),
                    ));
                  }
                });

                Navigator.pop(dialogContext);
              },
              child: Text(
                isEdit ? 'ບັນທຶກການແກ້ໄຂ' : 'ເພີ່ມແຜນຊື້',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deletePlanItem(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF85149), size: 20),
            SizedBox(width: 8),
            Text('ຢືນຢັນການລຶບ', style: TextStyle(color: Color(0xFFE6EDF3))),
          ],
        ),
        content: const Text('ທ່ານຕ້ອງການລຶບແຜນການຊື້ນີ້ແທ້ ຫຼື ບໍ່?', style: TextStyle(color: Color(0xFF8B949E))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ຍົກເລີກ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4D2A2A),
              foregroundColor: const Color(0xFFF85149),
            ),
            onPressed: () {
              setState(() => globalPlanItems.removeWhere((item) => item.id == id));
              Navigator.pop(ctx);
            },
            child: const Text('ລຶບ'),
          ),
        ],
      ),
    );
  }
}

// ==================== TAX PAGE ====================

// ==================== BUDGET PLAN PAGE ====================
class BudgetPlanPage extends StatefulWidget {
  const BudgetPlanPage({super.key});

  @override
  State<BudgetPlanPage> createState() => _BudgetPlanPageState();
}

class _BudgetPlanPageState extends State<BudgetPlanPage> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  String get _monthKey =>
      '${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}';

  String _fmt(double v) => '${NumberFormat('#,###', 'lo').format(v)} ₭';

  Color _statusColor(String status) {
    switch (status) {
      case 'ສຳເລັດ':
        return const Color(0xFF3FB950);
      case 'ກຳລັງດຳເນີນ':
        return const Color(0xFFD29922);
      case 'ຍົກເລີກ':
        return const Color(0xFFF85149);
      default:
        return const Color(0xFF8B949E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BudgetPlanItem>>(
      stream: BudgetPlanItemService.streamByMonth(_monthKey),
      builder: (context, snap) {
        final items = snap.data ?? [];
        final totalPlan = items.fold(0.0, (s, i) => s + i.plannedAmount);
        final totalUsed = items.fold(0.0, (s, i) => s + i.actualAmount);
        final totalLeft = totalPlan - totalUsed;

        return Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header + month picker
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      border: Border.all(color: const Color(0xFF30363D)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF1A4D2E), Color(0xFF238636)]),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(child: Text('📋', style: TextStyle(fontSize: 18))),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ແຜນການຊື້ເຄື່ອງປະຈຳເດືອນ',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFE6EDF3))),
                                  Text('ວາງແຜນງົບ ແລະ ຕິດຕາມ',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showBudgetDialog(),
                              icon: const Icon(Icons.add, size: 15),
                              label: const Text('ເພີ່ມລາຍການ', style: TextStyle(fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF238636),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Text('📅 ເດືອນ: ', style: TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
                            const SizedBox(width: 8),
                            DropdownButton<int>(
                              value: _selectedMonth,
                              dropdownColor: const Color(0xFF1C2128),
                              underline: const SizedBox(),
                              items: List.generate(12, (i) =>
                                  DropdownMenuItem(value: i + 1, child: Text(months[i], style: const TextStyle(fontSize: 13)))),
                              onChanged: (v) => setState(() => _selectedMonth = v!),
                            ),
                            const SizedBox(width: 12),
                            DropdownButton<int>(
                              value: _selectedYear,
                              dropdownColor: const Color(0xFF1C2128),
                              underline: const SizedBox(),
                              items: List.generate(5, (i) {
                                final y = DateTime.now().year - 1 + i;
                                return DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 13)));
                              }),
                              onChanged: (v) => setState(() => _selectedYear = v!),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Summary cards
                  Row(
                    children: [
                      _summaryCard('💰 ງົບທີ່ວາງແຜນ', _fmt(totalPlan), const Color(0xFF3FB950)),
                      const SizedBox(width: 10),
                      _summaryCard('🛒 ໃຊ້ໄປແລ້ວ', _fmt(totalUsed), const Color(0xFFF85149)),
                      const SizedBox(width: 10),
                      _summaryCard('📊 ຄົງເຫຼືອ', _fmt(totalLeft),
                          totalLeft >= 0 ? const Color(0xFF3FB950) : const Color(0xFFF85149)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Items table
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      border: Border.all(color: const Color(0xFF30363D)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF1d6a2e), Color(0xFF238636), Color(0xFF2ea043)]),
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                          ),
                          child: Row(
                            children: const [
                              SizedBox(width: 32, child: Text('#', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700))),
                              Expanded(flex: 3, child: Text('ລາຍການ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                              Expanded(flex: 2, child: Text('ໝວດ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                              Expanded(flex: 2, child: Text('ງົບ (₭)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                              Expanded(flex: 2, child: Text('ໃຊ້ (₭)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                              Expanded(flex: 2, child: Text('ສະຖານະ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                              SizedBox(width: 70),
                            ],
                          ),
                        ),
                        if (items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('ຍັງບໍ່ມີລາຍການ — ກົດ "ເພີ່ມລາຍການ" ເພື່ອເລີ່ມ',
                                style: TextStyle(color: Color(0xFF8B949E))),
                          )
                        else
                          ...items.asMap().entries.map((e) => _buildBudgetRow(e.key, e.value)),
                        // Footer total
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A4D2E).withValues(alpha: 0.3),
                            border: const Border(top: BorderSide(color: Color(0xFF3FB950))),
                            borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 32),
                              const Expanded(flex: 3, child: SizedBox()),
                              const Expanded(flex: 2, child: Text('ລວມທັງໝົດ:',
                                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 12), textAlign: TextAlign.right)),
                              const SizedBox(width: 4),
                              Expanded(flex: 2, child: Text(_fmt(totalPlan),
                                  style: const TextStyle(color: Color(0xFF3FB950), fontSize: 13, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                              Expanded(flex: 2, child: Text(_fmt(totalUsed),
                                  style: const TextStyle(color: Color(0xFFF85149), fontSize: 13, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                              const Expanded(flex: 2, child: SizedBox()),
                              const SizedBox(width: 70),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Signature section
                  _buildSignatureSection(items),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _summaryCard(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          border: Border.all(color: const Color(0xFF30363D)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetRow(int index, BudgetPlanItem item) {
    final pct = item.progressPct;
    final barColor = pct >= 100
        ? const Color(0xFFF85149)
        : pct >= 80
            ? const Color(0xFFD29922)
            : const Color(0xFF3FB950);

    return InkWell(
      onTap: () => _showBudgetDetail(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: index.isEven ? Colors.transparent : const Color(0xFF0D1117).withValues(alpha: 0.4),
          border: const Border(bottom: BorderSide(color: Color(0xFF21262D))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(color: const Color(0xFF21262D), borderRadius: BorderRadius.circular(4)),
                child: Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)))),
              ),
            ),
            Expanded(flex: 3, child: Text(item.itemName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFE6EDF3)))),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F6FEB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(item.category,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF58A6FF)), textAlign: TextAlign.center),
              ),
            ),
            Expanded(flex: 2, child: Text(_fmt(item.plannedAmount),
                style: const TextStyle(fontSize: 12, color: Color(0xFF3FB950)), textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text(_fmt(item.actualAmount),
                style: TextStyle(fontSize: 12, color: item.remaining < 0 ? const Color(0xFFF85149) : const Color(0xFFE6EDF3)),
                textAlign: TextAlign.right)),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Text(item.status, style: TextStyle(fontSize: 11, color: _statusColor(item.status), fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: const Color(0xFF21262D),
                      color: barColor,
                      minHeight: 4,
                    ),
                  ),
                  Text('${pct.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF8B949E)), textAlign: TextAlign.center),
                ],
              ),
            ),
            SizedBox(
              width: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _iconBtn(Icons.edit_outlined, const Color(0xFF58A6FF), () => _showBudgetDialog(item: item)),
                  const SizedBox(width: 4),
                  _iconBtn(Icons.delete_outline, const Color(0xFFF85149), () => _deleteBudgetItem(item)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _buildSignatureSection(List<BudgetPlanItem> items) {
    // Use first item's sig data (shared per month)
    final firstItem = items.isNotEmpty ? items.first : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border.all(color: const Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.draw_outlined, size: 16, color: Color(0xFF3FB950)),
              const SizedBox(width: 8),
              const Text('✍️ ລາຍເຊັນອະນຸມັດແຜນ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3))),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: budgetSignatureRoles.map((role) {
              final sigUrl = _getSigForRole(role, firstItem);
              return _buildSigBox(role, sigUrl, firstItem);
            }).toList(),
          ),
        ],
      ),
    );
  }

  String? _getSigForRole(String role, BudgetPlanItem? item) {
    if (item == null) return null;
    switch (role) {
      case 'ຜູ້ຮັບຜິດຊອບ': return item.sigApprover;
      case 'ຜູ້ອຳນວຍການ': return item.sigManager;
      case 'ຫົວໜ້າເຂື່ອນ': return item.sigChief;
      case 'ຜູ້ອະນຸມັດ': return item.sigFinance;
      default: return null;
    }
  }

  Widget _buildSigBox(String role, String? sigUrl, BudgetPlanItem? sampleItem) {
    final hasSig = sigUrl != null && sigUrl.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border.all(color: hasSig ? const Color(0xFF3FB950) : const Color(0xFF30363D),
            style: hasSig ? BorderStyle.solid : BorderStyle.solid),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            height: 56,
            alignment: Alignment.center,
            child: hasSig
                ? Image.network(sigUrl, height: 50, fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Color(0xFF8B949E)))
                : const Text('ຍັງບໍ່ເຊັນ', style: TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF30363D))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(role, style: const TextStyle(fontSize: 9, color: Color(0xFF8B949E)), overflow: TextOverflow.ellipsis)),
                if (!hasSig)
                  GestureDetector(
                    onTap: () => _signBudget(role),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A4D2E),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('✍️', style: TextStyle(fontSize: 10)),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => _clearBudgetSig(role),
                    child: const Icon(Icons.close, size: 12, color: Color(0xFFF85149)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _signBudget(String role) {
    // Show signature pad dialog - shared with accounting
    _showSignaturePadDialog(role);
  }

  void _clearBudgetSig(String role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('ລຶບລາຍເຊັນ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ຍົກເລີກ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ລຶບ', style: TextStyle(color: Color(0xFFF85149))),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    // Update all items in month to clear sig
    final snap = await FirebaseFirestore.instance
        .collection('budget_plan_items')
        .where('monthKey', isEqualTo: _monthKey)
        .get();
    for (final doc in snap.docs) {
      String? field;
      switch (role) {
        case 'ຜູ້ຮັບຜິດຊອບ': field = 'sigApprover'; break;
        case 'ຜູ້ອຳນວຍການ': field = 'sigManager'; break;
        case 'ຫົວໜ້າເຂື່ອນ': field = 'sigChief'; break;
        case 'ຜູ້ອະນຸມັດ': field = 'sigFinance'; break;
      }
      if (field != null) {
        await doc.reference.update({field: FieldValue.delete()});
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ລຶບລາຍເຊັນແລ້ວ')));
    }
  }

  void _showSignaturePadDialog(String role) {
    // Simple signature upload — pick image from gallery
    _pickSigImage(role);
  }

  Future<void> _pickSigImage(String role) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final url = await ReceiptStorageService.uploadReceipt(
        'sigs', bytes.toList(), 'budget_${role}_$_monthKey.jpg');
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ອັບໂຫລດລາຍເຊັນລົ້ມເຫລວ')));
      }
      return;
    }
    // Update all items in this month
    final snap = await FirebaseFirestore.instance
        .collection('budget_plan_items')
        .where('monthKey', isEqualTo: _monthKey)
        .get();
    String? field;
    switch (role) {
      case 'ຜູ້ຮັບຜິດຊອບ': field = 'sigApprover'; break;
      case 'ຜູ້ອຳນວຍການ': field = 'sigManager'; break;
      case 'ຫົວໜ້າເຂື່ອນ': field = 'sigChief'; break;
      case 'ຜູ້ອະນຸມັດ': field = 'sigFinance'; break;
    }
    if (field != null) {
      for (final doc in snap.docs) {
        await doc.reference.update({field: url});
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ ເຊັນສຳເລັດ')));
    }
  }

  void _showBudgetDetail(BudgetPlanItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFF1A4D2E), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.receipt_long, size: 16, color: Color(0xFF3FB950)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(item.itemName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3)))),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary grid
                Row(
                  children: [
                    _detailCard('ງົບວາງແຜນ', _fmt(item.plannedAmount), const Color(0xFF3FB950)),
                    const SizedBox(width: 8),
                    _detailCard('ໃຊ້ຈິງ', _fmt(item.actualAmount), const Color(0xFFF85149)),
                    const SizedBox(width: 8),
                    _detailCard('ຄົງເຫຼືອ', _fmt(item.remaining),
                        item.remaining >= 0 ? const Color(0xFF3FB950) : const Color(0xFFF85149)),
                  ],
                ),
                const SizedBox(height: 14),
                // Progress
                Text('ຄວາມຄືບໜ້າ ${item.progressPct.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.progressPct / 100,
                    backgroundColor: const Color(0xFF21262D),
                    color: item.progressPct >= 100 ? const Color(0xFFF85149) : const Color(0xFF3FB950),
                    minHeight: 8,
                  ),
                ),
                if (item.note.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(6)),
                    child: Text('📝 ${item.note}', style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
                  ),
                ],
                // Receipts
                if (item.receipts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('🧾 ໃບບິນ', style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: item.receipts.map((url) => GestureDetector(
                      onTap: () => _viewFullImage(ctx, url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover,
                            errorBuilder: (c, e, s) =>
                                const Icon(Icons.broken_image, color: Color(0xFF8B949E))),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ປິດ')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _showBudgetDialog(item: item); },
            child: const Text('✏️ ແກ້ໄຂ', style: TextStyle(color: Color(0xFF58A6FF))),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _deleteBudgetItem(item); },
            child: const Text('🗑 ລຶບ', style: TextStyle(color: Color(0xFFF85149))),
          ),
        ],
      ),
    );
  }

  Widget _detailCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(6)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF8B949E))),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  void _viewFullImage(BuildContext ctx, String url) {
    showDialog(
      context: ctx,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(c),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  void _showBudgetDialog({BudgetPlanItem? item}) async {
    final isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?.itemName ?? '');
    final planCtrl = TextEditingController(text: item != null ? item.plannedAmount.toString() : '');
    final usedCtrl = TextEditingController(text: item != null ? item.actualAmount.toString() : '');
    final noteCtrl = TextEditingController(text: item?.note ?? '');
    String selectedCat = item?.category ?? budgetCategories.first;
    String selectedStatus = item?.status ?? 'ວາງແຜນ';
    List<String> receipts = List.from(item?.receipts ?? []);

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          title: Text(isEdit ? 'ແກ້ໄຂລາຍການ' : 'ເພີ່ມລາຍການ',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3))),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Color(0xFFE6EDF3)),
                    decoration: const InputDecoration(labelText: 'ຊື່ລາຍການ *'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCat,
                          dropdownColor: const Color(0xFF1C2128),
                          decoration: const InputDecoration(labelText: 'ໝວດໝູ່'),
                          items: budgetCategories.map((c) =>
                              DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setS(() => selectedCat = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          dropdownColor: const Color(0xFF1C2128),
                          decoration: const InputDecoration(labelText: 'ສະຖານະ'),
                          items: const [
                            DropdownMenuItem(value: 'ວາງແຜນ', child: Text('📝 ວາງແຜນ')),
                            DropdownMenuItem(value: 'ກຳລັງດຳເນີນ', child: Text('🔄 ກຳລັງດຳເນີນ')),
                            DropdownMenuItem(value: 'ສຳເລັດ', child: Text('✅ ສຳເລັດ')),
                            DropdownMenuItem(value: 'ຍົກເລີກ', child: Text('❌ ຍົກເລີກ')),
                          ],
                          onChanged: (v) => setS(() => selectedStatus = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: planCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFFE6EDF3)),
                          decoration: const InputDecoration(labelText: 'ງົບວາງແຜນ (₭) *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: usedCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFFE6EDF3)),
                          decoration: const InputDecoration(labelText: 'ໃຊ້ຈິງ (₭)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    style: const TextStyle(color: Color(0xFFE6EDF3)),
                    decoration: const InputDecoration(labelText: 'ໝາຍເຫດ'),
                  ),
                  const SizedBox(height: 16),
                  // Receipt upload section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      border: Border.all(color: const Color(0xFF30363D)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('📎 ຮູບໃບບິນ', style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                    source: ImageSource.gallery, imageQuality: 80);
                                if (picked == null) return;
                                final bytes = await picked.readAsBytes();
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('⏳ ກຳລັງອັບໂຫລດ...')));
                                final url = await ReceiptStorageService.uploadReceipt(
                                    'receipts', bytes.toList(), picked.name);
                                if (url != null) {
                                  setS(() => receipts.add(url));
                                }
                              },
                              icon: const Icon(Icons.add_photo_alternate_outlined, size: 14),
                              label: const Text('ເພີ່ມ', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF3FB950)),
                            ),
                          ],
                        ),
                        if (receipts.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: receipts.asMap().entries.map((e) => Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(e.value, width: 56, height: 56, fit: BoxFit.cover,
                                      errorBuilder: (c, er, s) =>
                                          const Icon(Icons.broken_image, color: Color(0xFF8B949E))),
                                ),
                                Positioned(
                                  top: 0, right: 0,
                                  child: GestureDetector(
                                    onTap: () => setS(() => receipts.removeAt(e.key)),
                                    child: Container(
                                      width: 16, height: 16,
                                      decoration: const BoxDecoration(color: Color(0xFFF85149), shape: BoxShape.circle),
                                      child: const Icon(Icons.close, size: 10, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            )).toList(),
                          ),
                        ] else
                          const Text('ຍັງບໍ່ມີຮູບໃບບິນ', style: TextStyle(fontSize: 11, color: Color(0xFF484F58))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ຍົກເລີກ'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final plan = double.tryParse(planCtrl.text) ?? 0;
                if (name.isEmpty || plan <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ກະລຸນາໃສ່ຊື່ ແລະ ງົບ')));
                  return;
                }
                final used = double.tryParse(usedCtrl.text) ?? 0;
                final budgetItem = BudgetPlanItem(
                  id: item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  itemName: name,
                  category: selectedCat,
                  plannedAmount: plan,
                  actualAmount: used,
                  status: selectedStatus,
                  note: noteCtrl.text.trim(),
                  monthKey: _monthKey,
                  receipts: receipts,
                  sigApprover: item?.sigApprover,
                  sigManager: item?.sigManager,
                  sigChief: item?.sigChief,
                  sigFinance: item?.sigFinance,
                );
                if (isEdit) {
                  await BudgetPlanItemService.update(budgetItem);
                } else {
                  await BudgetPlanItemService.add(budgetItem);
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? '✅ ແກ້ໄຂສຳເລັດ' : '✅ ເພີ່ມລາຍການສຳເລັດ')));
                }
              },
              child: Text(isEdit ? 'ບັນທຶກການແກ້ໄຂ' : 'ເພີ່ມລາຍການ',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteBudgetItem(BudgetPlanItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFF30363D))),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF85149), size: 20),
            SizedBox(width: 8),
            Text('ຢືນຢັນການລຶບ', style: TextStyle(color: Color(0xFFE6EDF3))),
          ],
        ),
        content: Text('ລຶບ "${item.itemName}" ແທ້ ຫຼື ບໍ່?',
            style: const TextStyle(color: Color(0xFF8B949E))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ຍົກເລີກ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4D2A2A), foregroundColor: const Color(0xFFF85149)),
            onPressed: () async {
              await BudgetPlanItemService.delete(item.id);
              if (ctx.mounted) Navigator.pop(ctx);
              // Delete receipts from storage
              for (final url in item.receipts) {
                await ReceiptStorageService.deleteReceipt(url);
              }
            },
            child: const Text('ລຶບ'),
          ),
        ],
      ),
    );
  }
}

// ==================== TAX PAGE ====================
class TaxPage extends StatefulWidget {
  const TaxPage({super.key});

  @override
  State<TaxPage> createState() => _TaxPageState();
}

class _TaxPageState extends State<TaxPage> {
  int _selectedTaxMenu = 2;
  final List<String> _taxMenus = [
    'VAT (ອາກອນມູນຄ່າເພີ່ມ)',
    'ອາກອນກຳໄລ',
    'ອາກອນລາຍໄດ້ພະນັກງານ',
    'ລາຍງານພາສີລວມ'
  ];

  final List<TaxRecord> _empRecords = [];
  final List<VatRecord> _vatRecords = [];
  final List<ProfitTaxRecord> _profitRecords = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _empRecords.addAll(TaxStorageService.loadEmployees());
    _vatRecords.addAll(TaxStorageService.loadVat());
    _profitRecords.addAll(TaxStorageService.loadProfit());
  }

  String _fmt(double v) => NumberFormat('#,###', 'lo').format(v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTaxMenuTabs(),
              const SizedBox(height: 20),
              if (_selectedTaxMenu == 0) _buildVatView(),
              if (_selectedTaxMenu == 1) _buildProfitTaxView(),
              if (_selectedTaxMenu == 2) _buildEmployeeTaxView(),
              if (_selectedTaxMenu == 3) _buildTaxReportView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaxMenuTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_taxMenus.length, (index) {
          final isSelected = _selectedTaxMenu == index;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? const Color(0xFF9E4343) : const Color(0xFF161B22),
                foregroundColor: isSelected ? Colors.white : const Color(0xFF8B949E),
                side: BorderSide(color: isSelected ? Colors.transparent : const Color(0xFF30363D)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() {
                  _selectedTaxMenu = index;
                  _searchQuery = '';
                });
              },
              child: Text(
                _taxMenus[index],
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVatView() {
    final filteredVat = _vatRecords.where((r) => r.invoiceNo.toLowerCase().contains(_searchQuery.toLowerCase()) || r.detail.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    return _buildTaxListView(
      title: 'VAT (ອາກອນມູນຄ່າເພີ່ມ)',
      children: filteredVat.map((r) => _buildVatCard(r)).toList(),
    );
  }

  Widget _buildProfitTaxView() {
    final filteredProfit = _profitRecords.where((r) => r.periodTitle.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    return _buildTaxListView(
      title: 'ອາກອນກຳໄລ',
      children: filteredProfit.map((r) => _buildProfitCard(r)).toList(),
    );
  }

  Widget _buildEmployeeTaxView() {
    final filteredEmployees = _empRecords.where((r) => r.employeeName.toLowerCase().contains(_searchQuery.toLowerCase()) || r.position.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    return _buildTaxListView(
      title: 'ອາກອນລາຍໄດ້ພະນັກງານ',
      children: filteredEmployees.map((r) => _buildEmployeeCard(r)).toList(),
    );
  }

  Widget _buildTaxReportView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border.all(color: const Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Text('ລາຍງານພາສີລວມຈະມາໃນອັນໄລກ່ອນໜ້າ', style: TextStyle(color: Color(0xFF8B949E))),
      ),
    );
  }

  Widget _buildTaxListView({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            border: Border.all(color: const Color(0xFF30363D)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: const InputDecoration(
                  hintText: 'ຄົ້ນຫາ...',
                  prefixIcon: Icon(Icons.search, size: 14),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),
              if (children.isEmpty)
                const Text('ບໍ່ພົບຂໍ້ມູນ', style: TextStyle(color: Color(0xFF8B949E)))
              else
                Column(children: children),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(TaxRecord record) {
    return _buildTaxCard(
      title: record.employeeName,
      subtitle: record.position,
      details: [
        'ເງິນເດືອນ: ${_fmt(record.grossSalary)}',
        'ອາກອນ: ${record.taxRate.toStringAsFixed(1)}%',
        'ອາກອນທີ່ຕ້ອງຈ່າຍ: ${_fmt(record.taxAmount)}',
        'ເງິນເດືອນຫລັງຫຼຸດ: ${_fmt(record.netSalary)}',
      ],
    );
  }

  Widget _buildVatCard(VatRecord record) {
    return _buildTaxCard(
      title: record.invoiceNo,
      subtitle: record.detail,
      details: [
        'ຈຳນວນກ່ອນພາສີ: ${_fmt(record.amountBeforeVat)}',
        'ອາກອນ: ${record.vatRate.toStringAsFixed(1)}%',
        'ພາສີທີ່ຕ້ອງຈ່າຍ: ${_fmt(record.vatAmount)}',
        'ລວມທັງໝົດ: ${_fmt(record.totalAmount)}',
      ],
    );
  }

  Widget _buildProfitCard(ProfitTaxRecord record) {
    return _buildTaxCard(
      title: record.periodTitle,
      subtitle: 'ລາຍຮັບ ${_fmt(record.totalRevenue)}',
      details: [
        'ລາຍຈ່າຍ: ${_fmt(record.totalExpense)}',
        'ກໍ່ລາຍກຳໄລ: ${_fmt(record.netProfit)}',
        'ອາກອນ: ${record.taxRate.toStringAsFixed(1)}%',
        'ອາກອນທີ່ຕ້ອງຈ່າຍ: ${_fmt(record.taxAmount)}',
      ],
    );
  }

  Widget _buildTaxCard({required String title, required String subtitle, required List<String> details}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border.all(color: const Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3))),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
          const SizedBox(height: 12),
          ...details.map((text) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
              )),
        ],
      ),
    );
  }
}

// ==================== UTILITIES ====================
String formatMoney(double amount) {
  final formatter = NumberFormat('#,###', 'lo');
  return '${formatter.format(amount.abs())} ₭';
}

String formatMoneyWithSign(double amount) {
  if (amount < 0) return '−${formatMoney(amount.abs())}';
  return formatMoney(amount);
}

// ຄຳນວນ balance ແຕ່ ບໍ່ save (Firestore ສ້າງ id ໃໝ່ທຸກຄັ້ງ)
List<Transaction> recalculateBalances(List<Transaction> transactions) {
  final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
  double balance = 0;
  for (var t in sorted) {
    balance += t.income - t.expense;
    t.balance = balance;
  }
  return sorted;
}

double getOpeningBalance(List<Transaction> transactions, int year, int month) {
  double balance = 0;
  for (var t in transactions) {
    if (t.date.year < year || (t.date.year == year && t.date.month < month)) {
      balance += t.income - t.expense;
    }
  }
  return balance;
}

double getTotalBalance(List<Transaction> transactions) {
  return transactions.fold(0.0, (acc, t) => acc + t.income - t.expense);
}

// ==================== MAIN SCREEN ====================
class MainScreen extends StatefulWidget {
  final AuthResult currentUser;
  final VoidCallback onLogout;

  const MainScreen({
    super.key,
    required this.currentUser,
    required this.onLogout,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  // ຂໍ້ມູນ real-time ຈາກ Firestore Streams
  List<Transaction> _transactions = [];
  Map<String, SignatureData> _signatures = {};

  @override
  Widget build(BuildContext context) {
    // ໃຊ້ StreamBuilder ສຳລັບ transactions
    return StreamBuilder<List<Transaction>>(
      stream: TransactionService.stream(),
      builder: (context, txSnap) {
        if (txSnap.hasData) {
          _transactions = recalculateBalances(txSnap.data!);
        }

        return StreamBuilder<Map<String, SignatureData>>(
          stream: SignatureService.stream(),
          builder: (context, sigSnap) {
            if (sigSnap.hasData) {
              _signatures = sigSnap.data!;
            }

            return Scaffold(
              body: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isSidebarCollapsed ? 0 : 240,
                    child: ClipRect(
                      child: Sidebar(
                        selectedIndex: _selectedIndex,
                        onItemSelected: (index) {
                          setState(() => _selectedIndex = index);
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: [
                              DashboardPage(transactions: _transactions),
                              const ShoppingListPage(),
                              const BudgetPlanPage(),
                              const TaxPage(),
                              AccountingPage(
                                transactions: _transactions,
                                signatures: _signatures,
                                onAddTransaction: (t) =>
                                    TransactionService.add(t),
                                onUpdateTransaction: (t) =>
                                    TransactionService.update(t),
                                onDeleteTransaction: (id) =>
                                    TransactionService.delete(id),
                                onUpdateSignature: (role, data) =>
                                    SignatureService.update(role, data),
                                onDeleteSignature: (role) =>
                                    SignatureService.delete(role),
                              ),
                              QuarterlyPage(transactions: _transactions),
                              AnnualPage(transactions: _transactions),
                              SettingsPage(
                                transactions: _transactions,
                                currentUser: widget.currentUser,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () =>
                setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
            tooltip: 'ເມນູ',
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              [
                'ພາບລວມ',
                'ບັນຊີລາຍການຊື້ເຄື່ອງ',
                'ແຜນການຊື້ເຄື່ອງ',
                'ອາກອນລາຍໄດ້',
                'ບັນຊີລາຍການ',
                'ສະຫຼຸບໄຕຣ໌ມາດ',
                'ສະຫຼຸບລາຍປີ',
                'ຕັ້ງຄ່າ',
              ][_selectedIndex],
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              _getCurrentDate(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2128),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 14, color: Color(0xFF3FB950)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.currentUser.name ?? 'User',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE6EDF3),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            onPressed: _confirmLogout,
            tooltip: 'ອອກຈາກລະບົບ',
            color: const Color(0xFF8B949E),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ອອກຈາກລະບົບ'),
        content: const Text('ທ່ານຕ້ອງການອອກຈາກລະບົບແທ້ ຫຼື ບໍ່?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ຍົກເລີກ'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
            },
            child: const Text(
              'ອອກ',
              style: TextStyle(color: Color(0xFFF85149)),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

// ==================== SIDEBAR ====================
class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      child: Column(
        children: [
          _buildLogo(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('ຫຼັກ'),
                  _buildNavItem(0, Icons.dashboard, 'ພາບລວມ'),
                  _buildSectionLabel('ບັນຊີ'),
                  _buildNavItem(1, Icons.shopping_cart, 'ບັນຊີລາຍການຊື້ເຄື່ອງ'),
                  _buildNavItem(2, Icons.assignment_outlined, 'ແຜນການຊື້ເຄື່ອງ'),
                  _buildNavItem(3, Icons.receipt_long_outlined, 'ອາກອນລາຍໄດ້'),
                  _buildNavItem(4, Icons.receipt, 'ບັນຊີລາຍການ'),
                  _buildSectionLabel('ລາຍງານ'),
                  _buildNavItem(5, Icons.bar_chart, 'ສະຫຼຸບໄຕຣ໌ມາດ'),
                  _buildNavItem(6, Icons.trending_up, 'ສະຫຼຸບລາຍປີ'),
                  _buildSectionLabel('ລະບົບ'),
                  _buildNavItem(7, Icons.settings, 'ຕັ້ງຄ່າ'),
                  const SizedBox(height: 16),
                  _buildStatusFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF238636), Color(0xFF3FB950)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(child: Text('⚡', style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Nam',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'Sor',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3FB950),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Text(
                  'HyDroPower',
                  style: TextStyle(fontSize: 10, color: Color(0xFF484F58)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF484F58),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = selectedIndex == index;
    return InkWell(
      onTap: () => onItemSelected(index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: isSelected ? const Color(0xFF1C2128) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF3FB950)
                  : const Color(0xFF8B949E),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF3FB950)
                      : const Color(0xFF8B949E),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF3FB950),
            ),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'ລະບົບທຳງານປົກກະຕິ',
              style: TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== DASHBOARD PAGE ====================
class DashboardPage extends StatefulWidget {
  final List<Transaction> transactions;

  const DashboardPage({super.key, required this.transactions});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final currentMonthTx = widget.transactions
        .where(
          (t) => t.date.year == currentYear && t.date.month == currentMonth,
        )
        .toList();

    final totalIncome = currentMonthTx.fold(0.0, (s, t) => s + t.income);
    final totalExpense = currentMonthTx.fold(0.0, (s, t) => s + t.expense);
    final net = totalIncome - totalExpense;
    final overallBalance = getTotalBalance(widget.transactions);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            'ພາບລວມການເງິນ',
            'ສະຫຼຸບ — ${months[currentMonth - 1]} $currentYear',
          ),
          const SizedBox(height: 20),
          _buildStatsGrid(totalIncome, totalExpense, net, overallBalance),
          const SizedBox(height: 16),
          _buildBarChart(),
          const SizedBox(height: 16),
          _buildDashboardGrid(currentMonthTx, overallBalance),
        ],
      ),
    );
  }

  Widget _buildPageHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(
    double income,
    double expense,
    double net,
    double balance,
  ) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      children: [
        _StatCard(
          label: '💰 ລາຍຮັບເດືອນນີ້',
          value: formatMoney(income),
          color: const Color(0xFF3FB950),
        ),
        _StatCard(
          label: '💸 ລາຍຈ່າຍເດືອນນີ້',
          value: formatMoney(expense),
          color: const Color(0xFFF85149),
        ),
        _StatCard(
          label: '📊 ສຸດທິເດືອນນີ້',
          value: formatMoneyWithSign(net),
          color: net >= 0 ? const Color(0xFF3FB950) : const Color(0xFFF85149),
        ),
        _StatCard(
          label: '🏦 ຍອດຄົງເຫຼືອທັງໝົດ',
          value: formatMoneyWithSign(balance),
          color: const Color(0xFF58A6FF),
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    final maxValue = _getMaxMonthlyValue(_selectedYear);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '📊 ກຣາຟລາຍຮັບ-ລາຍຈ່າຍ 12 ເດືອນ',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Row(
                  children: [
                    const Text(
                      'ປີ:',
                      style: TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _selectedYear,
                      dropdownColor: const Color(0xFF1C2128),
                      underline: const SizedBox(),
                      items: [
                        DateTime.now().year - 3,
                        DateTime.now().year - 2,
                        DateTime.now().year - 1,
                        DateTime.now().year,
                        DateTime.now().year + 1,
                      ]
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text(y.toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedYear = value!),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _LegendDot(color: const Color(0xFF3FB950), label: 'ລາຍຮັບ'),
                const SizedBox(width: 16),
                _LegendDot(color: const Color(0xFFF85149), label: 'ລາຍຈ່າຍ'),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(12, (i) {
                    final month = i + 1;
                    double inc = 0, exp = 0;
                    for (var t in widget.transactions) {
                      if (t.date.year == _selectedYear &&
                          t.date.month == month) {
                        inc += t.income;
                        exp += t.expense;
                      }
                    }
                    final incHeight =
                        maxValue > 0 ? (inc / maxValue * 120) : 0.0;
                    final expHeight =
                        maxValue > 0 ? (exp / maxValue * 120) : 0.0;
                    return _BarColumn(
                      month: month,
                      inc: inc,
                      exp: exp,
                      incHeight: incHeight,
                      expHeight: expHeight,
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxMonthlyValue(int year) {
    double maxVal = 0;
    for (int m = 1; m <= 12; m++) {
      double inc = 0, exp = 0;
      for (var t in widget.transactions) {
        if (t.date.year == year && t.date.month == m) {
          inc += t.income;
          exp += t.expense;
        }
      }
      if (inc > maxVal) maxVal = inc;
      if (exp > maxVal) maxVal = exp;
    }
    return maxVal;
  }

  Widget _buildDashboardGrid(
    List<Transaction> currentMonthTx,
    double overallBalance,
  ) {
    final recentTx = widget.transactions.reversed.take(8).toList();
    final total =
        currentMonthTx.fold(0.0, (s, t) => s + t.income + t.expense);
    final incPct = total > 0
        ? (currentMonthTx.fold(0.0, (s, t) => s + t.income) / total * 100)
        : 0.0;
    final expPct = total > 0
        ? (currentMonthTx.fold(0.0, (s, t) => s + t.expense) / total * 100)
        : 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '🕐 ລາຍການລ່າສຸດ',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: recentTx.isEmpty
                      ? const Center(
                          child: Text(
                            'ຍັງບໍ່ມີລາຍການ',
                            style: TextStyle(color: Color(0xFF8B949E)),
                          ),
                        )
                      : Column(
                          children: recentTx
                              .map((t) => _RecentItemTile(transaction: t))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _RatioRow(
                        label: 'ລາຍຮັບ',
                        percent: incPct,
                        color: const Color(0xFF3FB950),
                      ),
                      const SizedBox(height: 8),
                      _RatioRow(
                        label: 'ລາຍຈ່າຍ',
                        percent: expPct,
                        color: const Color(0xFFF85149),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatRow(
                        label: 'ທຸລະກຳທັງໝົດ',
                        value: '${widget.transactions.length}',
                      ),
                      const SizedBox(height: 8),
                      _StatRow(
                        label: 'ຍອດຄົງເຫຼືອທັງໝົດ',
                        value: formatMoneyWithSign(overallBalance),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==================== SMALL WIDGETS ====================
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
        ),
      ],
    );
  }
}

class _BarColumn extends StatelessWidget {
  final int month;
  final double inc;
  final double exp;
  final double incHeight;
  final double expHeight;

  const _BarColumn({
    required this.month,
    required this.inc,
    required this.exp,
    required this.incHeight,
    required this.expHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 12,
                height: incHeight.clamp(2.0, 120.0),
                decoration: const BoxDecoration(
                  color: Color(0xFF3FB950),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
              const SizedBox(width: 2),
              Container(
                width: 12,
                height: expHeight.clamp(2.0, 120.0),
                decoration: const BoxDecoration(
                  color: Color(0xFFF85149),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            monthsShort[month - 1],
            style: const TextStyle(fontSize: 9, color: Color(0xFF484F58)),
          ),
        ],
      ),
    );
  }
}

class _RecentItemTile extends StatelessWidget {
  final Transaction transaction;
  const _RecentItemTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.income > 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF21262D))),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isIncome
                  ? const Color(0xFF3FB950)
                  : const Color(0xFFF85149),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.desc,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B949E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isIncome
                            ? const Color(0xFF1A4D2E)
                            : const Color(0xFF4D2A2A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isIncome ? 'ຮັບ' : 'ຈ່າຍ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isIncome
                              ? const Color(0xFF3FB950)
                              : const Color(0xFFF85149),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatMoney(
                    isIncome ? transaction.income : transaction.expense),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isIncome
                      ? const Color(0xFF3FB950)
                      : const Color(0xFFF85149),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatioRow extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;

  const _RatioRow({
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
            ),
            Text(
              '${percent.toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percent / 100,
          backgroundColor: const Color(0xFF1C2128),
          color: color,
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE6EDF3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== ACCOUNTING PAGE ====================
class AccountingPage extends StatefulWidget {
  final List<Transaction> transactions;
  final Map<String, SignatureData> signatures;
  final Function(Transaction) onAddTransaction;
  final Function(Transaction) onUpdateTransaction;
  final Function(String) onDeleteTransaction;
  final Function(String, SignatureData) onUpdateSignature;
  final Function(String) onDeleteSignature;

  const AccountingPage({
    super.key,
    required this.transactions,
    required this.signatures,
    required this.onAddTransaction,
    required this.onUpdateTransaction,
    required this.onDeleteTransaction,
    required this.onUpdateSignature,
    required this.onDeleteSignature,
  });

  @override
  State<AccountingPage> createState() => _AccountingPageState();
}

class _AccountingPageState extends State<AccountingPage> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredTx = widget.transactions
        .where(
          (t) =>
              t.date.year == _selectedYear &&
              t.date.month == _selectedMonth &&
              (_searchQuery.isEmpty ||
                  t.desc.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  t.note.toLowerCase().contains(_searchQuery.toLowerCase())),
        )
        .toList();

    final monthAllTx = widget.transactions
        .where(
          (t) =>
              t.date.year == _selectedYear &&
              t.date.month == _selectedMonth,
        )
        .toList();

    final openingBalance = getOpeningBalance(
      widget.transactions,
      _selectedYear,
      _selectedMonth,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildDocumentHeader(),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                _buildCardHeader(),
                _buildFilterBar(),
                SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildTransactionTable(filteredTx),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildStatsSummary(monthAllTx, openingBalance),
          const SizedBox(height: 16),
          _buildSignatureSection(),
        ],
      ),
    );
  }

  Widget _buildDocumentHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2128),
        border: Border.all(color: const Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Text(
            'ສາທາລະນະລັດ ປະຊາທິປະໄຕ ປະຊາຊົນລາວ',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const Text(
            'ສັນຕິພາບ ເອກະລາດ ປະຊາທິປະໄຕ ເອກະພາບ ວັດທະນະຖາວອນ',
            style: TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            '📒 ບັນຊີລາຍຮັບ-ລາຍຈ່າຍເງິນແຮສະໜາມ',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const Text(
            'ບໍລິສັດ: ເຂື່ອນໄຟຟ້ານ້ຳຊໍ້ ເມືອງວຽງທອງ ແຂວງບໍລິຄຳໄຊ',
            style: TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '📅 ເດືອນ: ${months[_selectedMonth - 1]} $_selectedYear',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF484F58)),
              ),
              const SizedBox(width: 20),
              const Text(
                '📍 ສະຖານທີ່: ພາກສະໜາມ',
                style: TextStyle(fontSize: 12, color: Color(0xFF484F58)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '📄 ລາຍການເງິນ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download, size: 18),
            onPressed: _exportCSV,
            tooltip: 'Export CSV',
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: () => _showTransactionDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('ເພີ່ມລາຍການ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          DropdownButton<int>(
            value: _selectedMonth,
            dropdownColor: const Color(0xFF1C2128),
            underline: const SizedBox(),
            items: List.generate(
              12,
              (i) => DropdownMenuItem(value: i + 1, child: Text(months[i])),
            ),
            onChanged: (value) => setState(() => _selectedMonth = value!),
          ),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _selectedYear,
            dropdownColor: const Color(0xFF1C2128),
            underline: const SizedBox(),
            items: [
              DateTime.now().year - 3,
              DateTime.now().year - 2,
              DateTime.now().year - 1,
              DateTime.now().year,
              DateTime.now().year + 1,
            ]
                .map(
                  (y) => DropdownMenuItem(value: y, child: Text(y.toString())),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedYear = value!),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                hintText: 'ຄົ້ນຫາ...',
                prefixIcon: Icon(Icons.search, size: 14),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTable(List<Transaction> txList) {
    if (txList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Text(
            'ບໍ່ມີລາຍການໃນເດືອນນີ້',
            style: TextStyle(color: Color(0xFF8B949E)),
          ),
        ),
      );
    }

    return DataTable(
      columns: const [
        DataColumn(label: Text('ລ/ດ')),
        DataColumn(label: Text('ວັນທີ')),
        DataColumn(label: Text('ເນື້ອໃນ')),
        DataColumn(label: Text('ລາຍຮັບ')),
        DataColumn(label: Text('ລາຍຈ່າຍ')),
        DataColumn(label: Text('ຍອດ')),
        DataColumn(label: Text('ໝາຍເຫດ')),
        DataColumn(label: Text('ຈັດການ')),
      ],
      rows: List.generate(txList.length, (i) {
        final t = txList[i];
        return DataRow(cells: [
          DataCell(Text('${i + 1}',
              style: const TextStyle(color: Color(0xFF8B949E)))),
          DataCell(Text(
            '${t.date.day}/${t.date.month}/${t.date.year}',
            style: const TextStyle(fontFamily: 'IBM Plex Mono', fontSize: 12),
          )),
          DataCell(Text(t.desc)),
          DataCell(Text(
            t.income > 0 ? formatMoney(t.income) : '-',
            style: const TextStyle(color: Color(0xFF3FB950)),
          )),
          DataCell(Text(
            t.expense > 0 ? formatMoney(t.expense) : '-',
            style: const TextStyle(color: Color(0xFFF85149)),
          )),
          DataCell(Text(
            formatMoneyWithSign(t.balance),
            style: TextStyle(
              color: t.balance >= 0
                  ? const Color(0xFF3FB950)
                  : const Color(0xFFF85149),
            ),
          )),
          DataCell(Text(
            t.note.isNotEmpty ? t.note : '-',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
          )),
          DataCell(Row(children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 16),
              onPressed: () => _showTransactionDialog(transaction: t),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 16),
              onPressed: () => _deleteTransaction(t.id),
            ),
          ])),
        ]);
      }),
    );
  }

  Widget _buildStatsSummary(
      List<Transaction> monthTx, double openingBalance) {
    final totalInc = monthTx.fold(0.0, (s, t) => s + t.income);
    final totalExp = monthTx.fold(0.0, (s, t) => s + t.expense);
    final closingBalance = openingBalance + totalInc - totalExp;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2128),
        border: Border.all(color: const Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
            label: 'ຍອດຍົກມາ',
            value: formatMoneyWithSign(openingBalance),
            color: const Color(0xFF8B949E),
          ),
          _SummaryItem(
            label: 'ລາຍຮັບ',
            value: formatMoney(totalInc),
            color: const Color(0xFF3FB950),
          ),
          _SummaryItem(
            label: 'ລາຍຈ່າຍ',
            value: formatMoney(totalExp),
            color: const Color(0xFFF85149),
          ),
          _SummaryItem(
            label: 'ຍອດຄົງເຫຼືອ',
            value: formatMoneyWithSign(closingBalance),
            color: closingBalance >= 0
                ? const Color(0xFF3FB950)
                : const Color(0xFFF85149),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2128),
        border: Border.all(color: const Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✍️ ລາຍເຊັນອະນຸຍາດ',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: signatureRoles.map((role) {
              return SizedBox(
                width: 200,
                child: _SignatureBox(
                  role: role,
                  signature: widget.signatures[role],
                  onUpdate: (data) => widget.onUpdateSignature(role, data),
                  onDelete: () => widget.onDeleteSignature(role),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showTransactionDialog({Transaction? transaction}) async {
    final isEdit = transaction != null;
    DateTime selectedDate = transaction?.date ?? DateTime.now();
    bool isIncome = transaction?.income != null && transaction!.income > 0;

    final descController = TextEditingController(text: transaction?.desc ?? '');
    final amountController = TextEditingController(
      text: isEdit
          ? (isIncome
                  ? transaction.income
                  : transaction.expense)
              .toStringAsFixed(0)
          : '',
    );
    final noteController = TextEditingController(text: transaction?.note ?? '');

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'ແກ້ໄຂລາຍການ' : 'ເພີ່ມລາຍການ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                      labelText: 'ເນື້ອໃນລາຍການ'),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('💰 ລາຍຮັບ')),
                    ButtonSegment(value: false, label: Text('💸 ລາຍຈ່າຍ')),
                  ],
                  selected: {isIncome},
                  onSelectionChanged: (set) =>
                      setDialogState(() => isIncome = set.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration:
                      const InputDecoration(labelText: 'ຈຳນວນເງິນ (₭)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration:
                      const InputDecoration(labelText: 'ໝາຍເຫດ (ຖ້າມີ)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ຍົກເລີກ'),
            ),
            ElevatedButton(
              onPressed: () {
                final desc = descController.text.trim();
                final amount = double.tryParse(amountController.text) ?? 0;
                if (desc.isEmpty || amount <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text('ກະລຸນາປ້ອນຂໍ້ມູນໃຫ້ຄົບ')),
                  );
                  return;
                }
                final t = Transaction(
                  id: isEdit
                      ? transaction.id
                      : DateTime.now().millisecondsSinceEpoch.toString(),
                  date: selectedDate,
                  desc: desc,
                  income: isIncome ? amount : 0,
                  expense: isIncome ? 0 : amount,
                  note: noteController.text,
                );
                if (isEdit) {
                  widget.onUpdateTransaction(t);
                } else {
                  widget.onAddTransaction(t);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(isEdit ? 'ບັນທຶກ' : 'ເພີ່ມ'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTransaction(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ຢືນຢັນການລຶບ'),
        content: const Text('ທ່ານຕ້ອງການລຶບລາຍການນີ້ແທ້ ຫຼື ບໍ່?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ຍົກເລີກ'),
          ),
          TextButton(
            onPressed: () {
              widget.onDeleteTransaction(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(
              'ລຶບ',
              style: TextStyle(color: Color(0xFFF85149)),
            ),
          ),
        ],
      ),
    );
  }

  void _exportCSV() {
    final txList = widget.transactions
        .where(
          (t) =>
              t.date.year == _selectedYear &&
              t.date.month == _selectedMonth,
        )
        .toList();
    final opening = getOpeningBalance(
        widget.transactions, _selectedYear, _selectedMonth);
    double rb = opening;

    List<String> lines = [
      '\uFEFFລ/ດ,ວັນທີ,ເນື້ອໃນ,ລາຍຮັບ(₭),ລາຍຈ່າຍ(₭),ຍອດເຫຼືອ(₭),ໝາຍເຫດ',
    ];

    for (int i = 0; i < txList.length; i++) {
      final t = txList[i];
      rb += t.income - t.expense;
      lines.add(
        '${i + 1},${t.date.day}/${t.date.month}/${t.date.year},"${t.desc}",${t.income},${t.expense},$rb,"${t.note}"',
      );
    }

    final totalInc = txList.fold(0.0, (s, t) => s + t.income);
    final totalExp = txList.fold(0.0, (s, t) => s + t.expense);
    lines.add(
        ',,ລວມ,$totalInc,$totalExp,${opening + totalInc - totalExp},');

    final blob = html.Blob([lines.join('\n')], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrl(blob);
    html.AnchorElement(href: url)
      ..download =
          'acc_${months[_selectedMonth - 1]}_$_selectedYear.csv'
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ==================== SIGNATURE BOX ====================
class _SignatureBox extends StatefulWidget {
  final String role;
  final SignatureData? signature;
  final Function(SignatureData) onUpdate;
  final VoidCallback onDelete;

  const _SignatureBox({
    required this.role,
    this.signature,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_SignatureBox> createState() => _SignatureBoxState();
}

class _SignatureBoxState extends State<_SignatureBox> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.signature?.name ?? '');
  }

  @override
  void didUpdateWidget(covariant _SignatureBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.signature?.name != oldWidget.signature?.name) {
      _nameController.text = widget.signature?.name ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSignature = widget.signature?.approved == true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border.all(color: const Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            widget.role,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8B949E),
            ),
          ),
          const SizedBox(height: 8),
          if (hasSignature)
            Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF3FB950)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text(
                  '✅ ອະນຸຍາດ',
                  style: TextStyle(fontSize: 11, color: Color(0xFF3FB950)),
                ),
              ),
            )
          else
            Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF30363D)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text(
                  'ຍັງບໍ່ເຊັນ',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (hasSignature)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _showSignatureDialog(context),
                  child: const Text('ແກ້ໄຂ',
                      style: TextStyle(fontSize: 11)),
                ),
                TextButton(
                  onPressed: widget.onDelete,
                  child: const Text(
                    'ລຶບ',
                    style: TextStyle(fontSize: 11, color: Color(0xFFF85149)),
                  ),
                ),
              ],
            )
          else
            ElevatedButton(
              onPressed: () => _showSignatureDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C2128),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
              ),
              child: const Text('✍️ ເຊັນ',
                  style: TextStyle(fontSize: 11)),
            ),
          const SizedBox(height: 4),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'ຊື່ ແລະ ນາມສະກຸນ...',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
            onChanged: (value) {
              widget.onUpdate(SignatureData(
                name: value,
                approved: widget.signature?.approved ?? false,
                dataUrl: widget.signature?.dataUrl,
                ts: widget.signature?.ts,
              ));
            },
          ),
          if (hasSignature) ...[
            const SizedBox(height: 4),
            Text(
              '✅ ອະນຸຍາດ ${widget.signature!.ts}',
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF3FB950)),
            ),
          ],
        ],
      ),
    );
  }

  void _showSignatureDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ເຊັນອະນຸຍາດ - ${widget.role}'),
        content: const Text('ຢືນຢັນການອະນຸຍາດ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ຍົກເລີກ'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onUpdate(SignatureData(
                approved: true,
                ts: '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                name: _nameController.text,
                dataUrl: widget.signature?.dataUrl,
              ));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('ຢືນຢັນ'),
          ),
        ],
      ),
    );
  }
}

// ==================== QUARTERLY PAGE ====================
class QuarterlyPage extends StatefulWidget {
  final List<Transaction> transactions;
  const QuarterlyPage({super.key, required this.transactions});

  @override
  State<QuarterlyPage> createState() => _QuarterlyPageState();
}

class _QuarterlyPageState extends State<QuarterlyPage> {
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ສະຫຼຸບໄຕຣ໌ມາດ',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'ສຽງ 4 ໄຕຣ໌ມາດ ຕໍ່ປີ',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF8B949E)),
                    ),
                  ],
                ),
              ),
              DropdownButton<int>(
                value: _selectedYear,
                dropdownColor: const Color(0xFF1C2128),
                underline: const SizedBox(),
                items: [
                  DateTime.now().year - 3,
                  DateTime.now().year - 2,
                  DateTime.now().year - 1,
                  DateTime.now().year,
                  DateTime.now().year + 1,
                ]
                    .map((y) => DropdownMenuItem(
                          value: y,
                          child: Text(y.toString()),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedYear = value!),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quarters.map((q) {
                final monthsList = q['months'] as List<int>;
                double inc = 0, exp = 0;
                for (var t in widget.transactions) {
                  if (t.date.year == _selectedYear &&
                      monthsList.contains(t.date.month)) {
                    inc += t.income;
                    exp += t.expense;
                  }
                }
                final net = inc - exp;
                return Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (q['color'] as Color)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  q['name'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: q['color'] as Color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                monthsList
                                    .map((m) => monthsShort[m - 1])
                                    .join(', '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8B949E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _QRow(
                              label: 'ລາຍຮັບ',
                              value: formatMoney(inc),
                              color: const Color(0xFF3FB950)),
                          const SizedBox(height: 6),
                          _QRow(
                              label: 'ລາຍຈ່າຍ',
                              value: formatMoney(exp),
                              color: const Color(0xFFF85149)),
                          const Divider(height: 16),
                          _QRow(
                            label: 'ສຸດທິ',
                            value: formatMoneyWithSign(net),
                            color: net >= 0
                                ? const Color(0xFF3FB950)
                                : const Color(0xFFF85149),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _QRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _QRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF8B949E))),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }
}

// ==================== ANNUAL PAGE ====================
class AnnualPage extends StatefulWidget {
  final List<Transaction> transactions;
  const AnnualPage({super.key, required this.transactions});

  @override
  State<AnnualPage> createState() => _AnnualPageState();
}

class _AnnualPageState extends State<AnnualPage> {
  int _selectedYear = DateTime.now().year;

  List<Map<String, double>> _getMonthlyData() {
    return List.generate(12, (i) {
      final month = i + 1;
      double inc = 0, exp = 0;
      for (var t in widget.transactions) {
        if (t.date.year == _selectedYear && t.date.month == month) {
          inc += t.income;
          exp += t.expense;
        }
      }
      return {'inc': inc, 'exp': exp};
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthlyData = _getMonthlyData();
    double totInc = 0, totExp = 0;
    for (final d in monthlyData) {
      totInc += d['inc']!;
      totExp += d['exp']!;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ສະຫຼຸບລາຍປີ',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'ຂໍ້ມູນລາຍຮັບ-ລາຍຈ່າຍ 12 ເດືອນ',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF8B949E)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.download, size: 18),
                onPressed: _exportAnnualCSV,
                tooltip: 'Export CSV',
              ),
              DropdownButton<int>(
                value: _selectedYear,
                dropdownColor: const Color(0xFF1C2128),
                underline: const SizedBox(),
                items: [
                  DateTime.now().year - 3,
                  DateTime.now().year - 2,
                  DateTime.now().year - 1,
                  DateTime.now().year,
                  DateTime.now().year + 1,
                ]
                    .map((y) => DropdownMenuItem(
                          value: y,
                          child: Text(y.toString()),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedYear = v!),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryItem(
                    label: 'ລາຍຮັບລວມ',
                    value: formatMoney(totInc),
                    color: const Color(0xFF3FB950),
                  ),
                  _SummaryItem(
                    label: 'ລາຍຈ່າຍລວມ',
                    value: formatMoney(totExp),
                    color: const Color(0xFFF85149),
                  ),
                  _SummaryItem(
                    label: 'ສຸດທິລວມ',
                    value: formatMoneyWithSign(totInc - totExp),
                    color: (totInc - totExp) >= 0
                        ? const Color(0xFF3FB950)
                        : const Color(0xFFF85149),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('ເດືອນ')),
                  DataColumn(label: Text('ລາຍຮັບ')),
                  DataColumn(label: Text('ລາຍຈ່າຍ')),
                  DataColumn(label: Text('ສຸດທິ')),
                ],
                rows: List.generate(12, (i) {
                  final d = monthlyData[i];
                  final net = (d['inc'] ?? 0) - (d['exp'] ?? 0);
                  return DataRow(cells: [
                    DataCell(Text(months[i])),
                    DataCell(Text(
                      formatMoney(d['inc'] ?? 0),
                      style: const TextStyle(color: Color(0xFF3FB950)),
                    )),
                    DataCell(Text(
                      formatMoney(d['exp'] ?? 0),
                      style: const TextStyle(color: Color(0xFFF85149)),
                    )),
                    DataCell(Text(
                      formatMoneyWithSign(net),
                      style: TextStyle(
                        color: net >= 0
                            ? const Color(0xFF3FB950)
                            : const Color(0xFFF85149),
                      ),
                    )),
                  ]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _exportAnnualCSV() {
    final monthlyData = _getMonthlyData();
    double cumul =
        getOpeningBalance(widget.transactions, _selectedYear, 1);
    final lines = [
      '\uFEFFເດືອນ,ລາຍຮັບ(₭),ລາຍຈ່າຍ(₭),ສຸດທິ(₭),ຍອດໂກຍ(₭)',
    ];
    double totInc = 0, totExp = 0;
    for (int i = 0; i < 12; i++) {
      final inc = monthlyData[i]['inc'] ?? 0.0;
      final exp = monthlyData[i]['exp'] ?? 0.0;
      cumul += inc - exp;
      totInc += inc;
      totExp += exp;
      lines.add('${months[i]},$inc,$exp,${inc - exp},$cumul');
    }
    lines.add('ລວມ,$totInc,$totExp,${totInc - totExp},');

    final blob = html.Blob([lines.join('\n')], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrl(blob);
    html.AnchorElement(href: url)
      ..download = 'annual_$_selectedYear.csv'
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

// ==================== SETTINGS PAGE ====================
class SettingsPage extends StatefulWidget {
  final List<Transaction> transactions;
  final AuthResult currentUser;

  const SettingsPage({
    super.key,
    required this.transactions,
    required this.currentUser,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Map<String, dynamic>> _allUsers = [];
  bool _loadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await FirebaseAuthService.getAllUsers();
    if (mounted) {
      setState(() {
        _allUsers = users;
        _loadingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = utf8
        .encode(jsonEncode(
            widget.transactions.map((t) => t.toJson()).toList()))
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ຕັ້ງຄ່າ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'ຈັດການຂໍ້ມູນລະບົບ',
            style: TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ຂໍ້ມູນ',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ຂໍ້ມູນທັງໝົດຖືກ sync ແບບ Real-time ຜ່ານ Firebase',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF3FB950)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _exportData,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export JSON'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _clearAllData(context),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('ລຶບຂໍ້ມູນທັງໝົດ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4D2A2A),
                          foregroundColor: const Color(0xFFF85149),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ລາຍການທັງໝົດ: ${widget.transactions.length} · ຂະໜາດ: ${(size / 1024).toStringAsFixed(2)} KB',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B949E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'ຜູ້ໃຊ້ທີ່ລົງທະບຽນ',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A4D2E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_allUsers.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF3FB950),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 16),
                        onPressed: _loadUsers,
                        tooltip: 'ໂຫຼດໃໝ່',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingUsers)
                    const Center(
                        child: CircularProgressIndicator(
                      color: Color(0xFF3FB950),
                    ))
                  else if (_allUsers.isEmpty)
                    const Text(
                      'ຍັງບໍ່ມີຜູ້ໃຊ້',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF8B949E)),
                    )
                  else
                    ..._allUsers.map((u) => _UserRow(
                          user: u,
                          isCurrentUser:
                              u['email'] == widget.currentUser.email,
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'ກ່ຽວກັບ',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  _AboutRow(
                      label: 'ລະບົບ:',
                      value: 'ບັນຊີລາຍຮັບ-ລາຍຈ່າຍ v4.0 (Firebase)'),
                  SizedBox(height: 8),
                  _AboutRow(
                    label: 'ຫົວໜ່ວຍ:',
                    value:
                        'ເຂື່ອນໄຟຟ້ານ້ຳຊໍ້ ເມືອງວຽງທອງ ແຂວງບໍລິຄຳໄຊ',
                  ),
                  SizedBox(height: 8),
                  _AboutRow(
                    label: 'ຄຸນສົມບັດ:',
                    value:
                        'ບັນຊີ, ກຣາຟ, ລາຍງານ, Export CSV, ເຊັນເອກະສານ, Real-time sync',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    final jsonData = jsonEncode(
        widget.transactions.map((t) => t.toJson()).toList());
    final blob = html.Blob([jsonData], 'application/json');
    final url = html.Url.createObjectUrl(blob);
    html.AnchorElement(href: url)
      ..download =
          'acc_${DateTime.now().toIso8601String().split('T')[0]}.json'
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _clearAllData(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ຢືນຢັນການລຶບຂໍ້ມູນ'),
        content: const Text(
          'ທ່ານຕ້ອງການລຶບຂໍ້ມູນທັງໝົດແທ້ ຫຼື ບໍ່?\nການກະທຳນີ້ຈະຖາວອນ ແລະ ທຸກ user ຈະໄດ້ຮັບຜົນ!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ຍົກເລີກ'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await TransactionService.deleteAll();
              await SignatureService.deleteAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('ລຶບຂໍ້ມູນທັງໝົດແລ້ວ')),
                );
              }
            },
            child: const Text(
              'ລຶບ',
              style: TextStyle(color: Color(0xFFF85149)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF8B949E)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFFE6EDF3)),
          ),
        ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isCurrentUser;
  const _UserRow({required this.user, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final createdAt = user['createdAt'] != null
        ? DateTime.tryParse(user['createdAt'] as String)
        : null;
    final dateStr = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Color(0xFF21262D))),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? const Color(0xFF1A4D2E)
                  : const Color(0xFF1C2128),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrentUser
                    ? const Color(0xFF3FB950)
                    : const Color(0xFF30363D),
              ),
            ),
            child: Center(
              child: Text(
                (user['name'] as String? ?? '?')[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isCurrentUser
                      ? const Color(0xFF3FB950)
                      : const Color(0xFF8B949E),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user['name'] as String? ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFE6EDF3),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A4D2E),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ທ່ານ',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF3FB950),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user['email'] as String? ?? '',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF8B949E)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (dateStr.isNotEmpty)
            Text(
              dateStr,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF484F58)),
            ),
        ],
      ),
    );
  }
}