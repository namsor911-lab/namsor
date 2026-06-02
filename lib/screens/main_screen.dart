import 'package:flutter/material.dart';

import 'package:accounting/models/models.dart';
import 'package:accounting/services/services.dart';
import 'package:accounting/utils/constants.dart';
import 'package:accounting/widgets/sidebar.dart';
import 'package:accounting/screens/accounting_page.dart';
import 'package:accounting/screens/annual_page.dart';
import 'package:accounting/screens/budget_plan_page.dart';
import 'package:accounting/screens/dashboard_page.dart';
import 'package:accounting/screens/quarterly_page.dart';
import 'package:accounting/screens/settings_page.dart';
import 'package:accounting/screens/shopping_list_page.dart';
import 'package:accounting/screens/tax_page.dart';

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
  List<Transaction> _transactions = [];
  Map<String, SignatureData> _signatures = {};

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
                                onAddTransaction: TransactionService.add,
                                onUpdateTransaction: TransactionService.update,
                                onDeleteTransaction: TransactionService.delete,
                                onUpdateSignature: SignatureService.update,
                                onDeleteSignature: SignatureService.delete,
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
            onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
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
                      style: const TextStyle(fontSize: 12, color: Color(0xFFE6EDF3)),
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
            child: const Text('ອອກ', style: TextStyle(color: Color(0xFFF85149))),
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
