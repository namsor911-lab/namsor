// main.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'firebase_options.dart';

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

// ==================== DATA MODELS ====================
class Transaction {
  final String id;
  final DateTime date;
  final String desc;
  final double income;
  final double expense;
  final String note;
  double balance;
  final String? receiptId;

  Transaction({
    required this.id,
    required this.date,
    required this.desc,
    required this.income,
    required this.expense,
    this.note = '',
    this.balance = 0,
    this.receiptId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'desc': desc,
    'income': income,
    'expense': expense,
    'note': note,
    'balance': balance,
    'receiptId': receiptId,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    desc: json['desc'] as String,
    income: (json['income'] as num?)?.toDouble() ?? 0.0,
    expense: (json['expense'] as num?)?.toDouble() ?? 0.0,
    note: json['note'] as String? ?? '',
    balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
    receiptId: json['receiptId'] as String?,
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
  String cat;
  double plan;
  double used;
  String status;
  String note;
  String? receiptId;

  PlanItem({
    required this.id,
    required this.itemName,
    required this.cat,
    required this.plan,
    required this.used,
    required this.status,
    this.note = '',
    this.receiptId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemName': itemName,
    'cat': cat,
    'plan': plan,
    'used': used,
    'status': status,
    'note': note,
    'receiptId': receiptId,
  };

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
    id: json['id'] as String,
    itemName: json['itemName'] as String,
    cat: json['cat'] as String? ?? 'ອຸປະກອນ',
    plan: (json['plan'] as num?)?.toDouble() ?? 0.0,
    used: (json['used'] as num?)?.toDouble() ?? 0.0,
    status: json['status'] as String? ?? 'ວາງແຜນ',
    note: json['note'] as String? ?? '',
    receiptId: json['receiptId'] as String?,
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
  'ຜູ້ຮັບຜິດຊອບ',
  'ຜູ້ອຳນວຍການ',
  'ຫົວໜ້າເຂື່ອນ',
  'ຜູ້ອະນຸມັດ',
];

// ==================== UTILITIES ====================
String formatMoney(double amount) {
  final formatter = NumberFormat('#,###', 'lo');
  return '${formatter.format(amount.abs())} ₭';
}

String formatMoneyWithSign(double amount) {
  if (amount < 0) return '−${formatMoney(amount.abs())}';
  return formatMoney(amount);
}

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

void showSoonDialog(BuildContext context, String title) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('⏳ $title — ກຳລັງພັດທະນາ...'),
      backgroundColor: const Color(0xFF1F4E79),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

// ==================== AUTH WRAPPER & PAGES ====================
class AuthPage extends StatefulWidget {
  final Function(AuthResult) onAuthenticated;
  const AuthPage({super.key, required this.onAuthenticated});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
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
    _tabController.addListener(() => setState(() => _errorMessage = null));
  }

  void _handleLogin() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    final result = await FirebaseAuthService.login(_loginEmailCtrl.text, _loginPasswordCtrl.text);
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
    setState(() { _isLoading = true; _errorMessage = null; });
    final result = await FirebaseAuthService.register(_regEmailCtrl.text, _regPasswordCtrl.text, _regNameCtrl.text);
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.flash_on, size: 64, color: Color(0xFF3FB950)),
                const SizedBox(height: 16),
                const Text('ເຂື່ອນໄຟຟ້ານ້ຳຊໍ້', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    border: Border.all(color: const Color(0xFF30363D)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        tabs: const [Tab(text: 'ເຂົ້າສູ່ລະບົບ'), Tab(text: 'ລົງທະບຽນ')],
                        indicatorColor: const Color(0xFF3FB950),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: _tabController.index == 0 ? _buildLoginForm() : _buildRegisterForm(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        if (_errorMessage != null) Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        TextField(controller: _loginEmailCtrl, decoration: const InputDecoration(labelText: 'ອີເມວ')),
        const SizedBox(height: 10),
        TextField(
          controller: _loginPasswordCtrl, 
          obscureText: _loginObscure, 
          decoration: InputDecoration(
            labelText: 'ລະຫັດຜ່ານ',
            suffixIcon: IconButton(
              icon: Icon(_loginObscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _loginObscure = !_loginObscure),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _handleLogin,
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: const Color(0xFF3FB950)),
          child: _isLoading ? const CircularProgressIndicator() : const Text('ເຂົ້າສູ່ລະບົບ'),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        if (_errorMessage != null) Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        TextField(controller: _regNameCtrl, decoration: const InputDecoration(labelText: 'ຊື່')),
        const SizedBox(height: 10),
        TextField(controller: _regEmailCtrl, decoration: const InputDecoration(labelText: 'ອີເມວ')),
        const SizedBox(height: 10),
        TextField(
          controller: _regPasswordCtrl, 
          obscureText: _regObscure, 
          decoration: InputDecoration(
            labelText: 'ລະຫັດຜ່ານ',
            suffixIcon: IconButton(
              icon: Icon(_regObscure ? Icons.visibility_off : Icons.visibility),
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
            suffixIcon: IconButton(
              icon: Icon(_regConfirmObscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _regConfirmObscure = !_regConfirmObscure),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _handleRegister,
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: const Color(0xFF238636)),
          child: _isLoading ? const CircularProgressIndicator() : const Text('ລົງທະບຽນ'),
        ),
      ],
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final user = snapshot.data;
        if (user == null) return AuthPage(onAuthenticated: (_) {});
        return MainScreen(
          currentUser: AuthResult(success: true, message: '', uid: user.uid, email: user.email, name: user.displayName),
          onLogout: () async => await FirebaseAuthService.logout(),
        );
      },
    );
  }
}

// ==================== MAIN SCREEN ====================
class MainScreen extends StatefulWidget {
  final AuthResult currentUser;
  final VoidCallback onLogout;

  const MainScreen({super.key, required this.currentUser, required this.onLogout});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  List<Transaction> _transactions = [];
  Map<String, SignatureData> _signatures = {};

  final List<PlanItem> _globalPlanItems = [];

  @override
  Widget build(BuildContext context) {
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
                          if (index == -1) return; // For coming soon items
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
                              ShoppingPlanPage(planItems: _globalPlanItems, signatures: _signatures),
                              const ShoppingListPage(),
                              AccountingPage(
                                transactions: _transactions,
                                signatures: _signatures,
                                onAddTransaction: (t) => TransactionService.add(t),
                                onUpdateTransaction: (t) => TransactionService.update(t),
                                onDeleteTransaction: (id) => TransactionService.delete(id),
                                onUpdateSignature: (role, data) => SignatureService.update(role, data),
                                onDeleteSignature: (role) => SignatureService.delete(role),
                              ),
                              QuarterlyPage(transactions: _transactions),
                              AnnualPage(transactions: _transactions),
                              SettingsPage(transactions: _transactions, currentUser: widget.currentUser),
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
    final titles = [
      'ພາບລວມ', 'ແຜນການຊື້ເຄື່ອງປະຈຳເດືອນ', 'ບັນຊີລາຍການຊື້ເຄື່ອງ',
      'ບັນຊີລາຍການ', 'ສະຫຼຸບໄຕຣ໌ມາດ', 'ສະຫຼຸບລາຍປີ', 'ຕັ້ງຄ່າ'
    ];
    
    final now = DateTime.now();
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.menu), onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed)),
          const SizedBox(width: 8),
          Text(titles[_selectedIndex], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${months[now.month - 1]} ${now.day}, ${now.year}', style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFF1C2128), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF30363D))),
            child: Row(
              children: [
                const Icon(Icons.person, size: 14, color: Color(0xFF3FB950)),
                const SizedBox(width: 6),
                Text(widget.currentUser.name ?? 'User', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            onPressed: () => widget.onLogout(),
            color: const Color(0xFF8B949E),
          ),
        ],
      ),
    );
  }
}

// ==================== SIDEBAR ====================
class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const Sidebar({super.key, required this.selectedIndex, required this.onItemSelected});

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
                  _buildSectionLabel('ໜ້າຫຼັກ'),
                  _buildNavItem(0, Icons.dashboard_outlined, 'ພາບລວມ'),
                  _buildNavItem(1, Icons.assignment_outlined, 'ແຜນການຊື້ເຄື່ອງ'),
                  _buildNavItem(2, Icons.shopping_cart_outlined, 'ບັນຊີລາຍການຊື້ເຄື່ອງ'),
                  _buildNavItem(3, Icons.receipt_long_outlined, 'ບັນຊີລາຍການ'),
                  
                  _buildSectionLabel('ລາຍງານ'),
                  _buildNavItem(4, Icons.bar_chart_outlined, 'ສະຫຼຸບໄຕຣ໌ມາດ'),
                  _buildNavItem(5, Icons.trending_up, 'ສະຫຼຸບລາຍປີ'),
                  
                  _buildSectionLabel('ຊັບພະຍາກອນມະນຸດ'),
                  _buildActionItem(context, Icons.people_outline, 'ລະບົບ HR'),
                  
                  _buildSectionLabel('ການຜະລິດໄຟຟ້າ'),
                  _buildActionItem(context, Icons.bolt_outlined, 'ແຜນການຜະລິດໄຟຟ້າ', badge: 'ໄວໆນີ້'),
                  _buildActionItem(context, Icons.calculate_outlined, 'ການຄຳນວນໂຫລດ/ວັນ', badge: 'ໄວໆນີ້'),
                  
                  _buildSectionLabel('ລະບົບ'),
                  _buildNavItem(6, Icons.settings_outlined, 'ຕັ້ງຄ່າ'),
                  
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
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF30363D)))),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF238636), Color(0xFF3FB950)]), borderRadius: BorderRadius.circular(6)),
            child: const Center(child: Text('⚡', style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NamSor', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF3FB950))),
              Text('HyDroPower', style: TextStyle(fontSize: 10, color: Color(0xFF484F58))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF484F58))),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = selectedIndex == index;
    return InkWell(
      onTap: () => onItemSelected(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 2, left: 8, right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: isSelected ? const Color(0xFF1C2128) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF3FB950) : const Color(0xFF8B949E)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: isSelected ? const Color(0xFF3FB950) : const Color(0xFF8B949E)))),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, IconData icon, String label, {String? badge}) {
    return InkWell(
      onTap: () => showSoonDialog(context, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 2, left: 8, right: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF8B949E)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E)))),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFD29922).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Text(badge, style: const TextStyle(fontSize: 9, color: Color(0xFFD29922))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF30363D)))),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF3FB950))),
          const SizedBox(width: 6),
          const Text('ລະບົບທຳງານປົກກະຕິ', style: TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
        ],
      ),
    );
  }
}

// ==================== DASHBOARD PAGE ====================
class DashboardPage extends StatelessWidget {
  final List<Transaction> transactions;

  const DashboardPage({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonthTx = transactions.where((t) => t.date.year == now.year && t.date.month == now.month).toList();
    final income = currentMonthTx.fold(0.0, (s, t) => s + t.income);
    final expense = currentMonthTx.fold(0.0, (s, t) => s + t.expense);
    final net = income - expense;
    final allBal = getTotalBalance(transactions);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ພາບລວມການເງິນ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Text('ສະຫຼຸບ — ${months[now.month - 1]} ${now.year}', style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
          const SizedBox(height: 20),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 1.5, crossAxisSpacing: 12),
            children: [
              _StatCard(label: '💰 ລາຍຮັບເດືອນນີ້', value: formatMoney(income), color: const Color(0xFF3FB950), hint: '${currentMonthTx.where((t) => t.income > 0).length} ລາຍການ'),
              _StatCard(label: '💸 ລາຍຈ່າຍເດືອນນີ້', value: formatMoney(expense), color: const Color(0xFFF85149), hint: '${currentMonthTx.where((t) => t.expense > 0).length} ລາຍການ'),
              _StatCard(label: '📊 ສຸດທິເດືອນນີ້', value: formatMoneyWithSign(net), color: net >= 0 ? const Color(0xFF3FB950) : const Color(0xFFF85149), hint: net >= 0 ? '✅ ກຳໄລ' : '⚠️ ຂາດທຶນ'),
              _StatCard(label: '🏦 ຍອດຄົງເຫຼືອທັງໝົດ', value: formatMoneyWithSign(allBal), color: const Color(0xFF58A6FF), hint: 'ທຸກລາຍການ'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, hint;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF30363D))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
          FittedBox(child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color))),
          Text(hint, style: const TextStyle(fontSize: 11, color: Color(0xFF484F58))),
        ],
      ),
    );
  }
}

// ==================== SHOPPING PLAN PAGE (BUDGET) ====================
class ShoppingPlanPage extends StatefulWidget {
  final List<PlanItem> planItems;
  final Map<String, SignatureData> signatures;

  const ShoppingPlanPage({super.key, required this.planItems, required this.signatures});

  @override
  State<ShoppingPlanPage> createState() => _ShoppingPlanPageState();
}

class _ShoppingPlanPageState extends State<ShoppingPlanPage> {
  // ເອົາ _selectedMonth ລະ _selectedYear ທີ່ບໍ່ໄດ້ໃຊ້ອອກແລ້ວ

  @override
  Widget build(BuildContext context) {
    double totalPlan = widget.planItems.fold(0.0, (s, i) => s + i.plan);
    double totalUsed = widget.planItems.fold(0.0, (s, i) => s + i.used);
    double totalLeft = totalPlan - totalUsed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ແຜນການຊື້ເຄື່ອງປະຈຳເດືອນ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const Text('ວາງແຜນງົບປະມານ ແລະ ຕິດຕາມການໃຊ້ຈ່າຍ', style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
          const SizedBox(height: 20),
          
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2.5, crossAxisSpacing: 12),
            children: [
              _StatCard(label: '💰 ງົບທີ່ວາງແຜນ', value: formatMoney(totalPlan), color: const Color(0xFF3FB950), hint: ''),
              _StatCard(label: '🛒 ໃຊ້ໄປແລ້ວ', value: formatMoney(totalUsed), color: const Color(0xFFF85149), hint: ''),
              _StatCard(label: '📊 ຄົງເຫຼືອ', value: formatMoneyWithSign(totalLeft), color: totalLeft >= 0 ? const Color(0xFF3FB950) : const Color(0xFFF85149), hint: ''),
            ],
          ),
          const SizedBox(height: 20),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF30363D))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('📋 ລາຍການແຜນການຊື້ເຄື່ອງ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ElevatedButton.icon(
                      onPressed: () => _showPlanDialog(),
                      icon: const Icon(Icons.add, size: 16), label: const Text('ເພີ່ມລາຍການ'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('ລ/ດ')),
                      DataColumn(label: Text('ລາຍການ')),
                      DataColumn(label: Text('ໝວດໝູ່')),
                      DataColumn(label: Text('ງົບວາງແຜນ')),
                      DataColumn(label: Text('ໃຊ້ຈິງ')),
                      DataColumn(label: Text('ສະຖານະ')),
                      DataColumn(label: Text('ໝາຍເຫດ')),
                      DataColumn(label: Text('ຈັດການ')),
                    ],
                    rows: List.generate(widget.planItems.length, (idx) {
                      final item = widget.planItems[idx];
                      return DataRow(cells: [
                        DataCell(Text('${idx + 1}')),
                        DataCell(Text(item.itemName)),
                        DataCell(Chip(label: Text(item.cat, style: const TextStyle(fontSize: 11)), backgroundColor: const Color(0xFF1C2128))),
                        DataCell(Text(formatMoney(item.plan), style: const TextStyle(color: Color(0xFF3FB950)))),
                        DataCell(Text(formatMoney(item.used), style: TextStyle(color: item.used > item.plan ? const Color(0xFFF85149) : Colors.white))),
                        DataCell(Text(item.status)),
                        DataCell(Text(item.note)),
                        DataCell(Row(
                          children: [
                            IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showPlanDialog(item: item)),
                            IconButton(icon: const Icon(Icons.delete, size: 16, color: Color(0xFFF85149)), onPressed: () {
                              setState(() => widget.planItems.remove(item));
                            }),
                          ],
                        )),
                      ]);
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPlanDialog({PlanItem? item}) async {
    final isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?.itemName);
    final planCtrl = TextEditingController(text: item?.plan.toString());
    final usedCtrl = TextEditingController(text: item?.used.toString());
    
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(isEdit ? 'ແກ້ໄຂລາຍການ' : 'ເພີ່ມລາຍການ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ລາຍການ')),
            const SizedBox(height: 10),
            TextField(controller: planCtrl, decoration: const InputDecoration(labelText: 'ງົບວາງແຜນ')),
            const SizedBox(height: 10),
            TextField(controller: usedCtrl, decoration: const InputDecoration(labelText: 'ໃຊ້ຈິງ')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ຍົກເລີກ')),
        ElevatedButton(
          onPressed: () {
            setState(() {
              if (isEdit) {
                item.itemName = nameCtrl.text;
                item.plan = double.tryParse(planCtrl.text) ?? 0.0;
                item.used = double.tryParse(usedCtrl.text) ?? 0.0;
              } else {
                widget.planItems.add(PlanItem(id: DateTime.now().toString(), itemName: nameCtrl.text, cat: 'ທົ່ວໄປ', plan: double.tryParse(planCtrl.text) ?? 0.0, used: double.tryParse(usedCtrl.text) ?? 0.0, status: 'ວາງແຜນ'));
              }
            });
            Navigator.pop(ctx);
          },
          child: const Text('ບັນທຶກ'),
        )
      ],
    ));
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
  // ເອົາ _selectedMonth ລະ _selectedYear ທີ່ບໍ່ໄດ້ໃຊ້ອອກແລ້ວ

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF1C2128), border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(10)),
            child: const Column(
              children: [
                Text('ສາທາລະນະລັດ ປະຊາທິປະໄຕ ປະຊາຊົນລາວ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text('ສັນຕິພາບ ເອກະລາດ ປະຊາທິປະໄຕ ເອກະພາບ ວັດທະນະຖາວອນ', style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
                SizedBox(height: 12),
                Divider(),
                SizedBox(height: 12),
                Text('📒 ບັນຊີລາຍຮັບ-ລາຍຈ່າຍເງິນແຮສະໜາມ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Center(child: Text("ຕາຕະລາງບັນຊີລາຍການ", style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }
}

// ==================== SHOPPING LIST PAGE ====================
class ShoppingListPage extends StatelessWidget {
  const ShoppingListPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("ໜ້າລາຍການຊື້ເຄື່ອງ (ປະຕິບັດງານຄ້າຍຄືກັນ)"));
  }
}

// ==================== QUARTERLY & ANNUAL PAGES ====================
class QuarterlyPage extends StatelessWidget {
  final List<Transaction> transactions;
  const QuarterlyPage({super.key, required this.transactions});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("ສະຫຼຸບໄຕຣ໌ມາດ"));
  }
}

class AnnualPage extends StatelessWidget {
  final List<Transaction> transactions;
  const AnnualPage({super.key, required this.transactions});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("ສະຫຼຸບລາຍປີ"));
  }
}

// ==================== SETTINGS PAGE ====================
class SettingsPage extends StatelessWidget {
  final List<Transaction> transactions;
  final AuthResult currentUser;
  const SettingsPage({super.key, required this.transactions, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ຕັ້ງຄ່າ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const Text('ຈັດການຂໍ້ມູນລະບົບ', style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4D2A2A)),
            child: const Text("ລຶບຂໍ້ມູນທັງໝົດ", style: TextStyle(color: Color(0xFFF85149))),
          )
        ],
      ),
    );
  }
}