// main.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';   // ສ້າງດ້ວຍ flutterfire configure
import 'auth_page.dart';
import 'firebase_service.dart' show FirebaseAuthService, TransactionService, SignatureService, AuthResult;
import 'shopping_page.dart';
import 'tax_page.dart';

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
                  _buildNavItem(2, Icons.receipt_long_outlined, 'ອາກອນລາຍໄດ້'),
                  _buildNavItem(3, Icons.receipt, 'ບັນຊີລາຍການ'),
                  _buildSectionLabel('ລາຍງານ'),
                  _buildNavItem(4, Icons.bar_chart, 'ສະຫຼຸບໄຕຣ໌ມາດ'),
                  _buildNavItem(5, Icons.trending_up, 'ສະຫຼຸບລາຍປີ'),
                  _buildSectionLabel('ລະບົບ'),
                  _buildNavItem(6, Icons.settings, 'ຕັ້ງຄ່າ'),
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