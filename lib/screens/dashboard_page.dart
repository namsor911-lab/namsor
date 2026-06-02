import 'package:flutter/material.dart';

import 'package:accounting/models/models.dart';
import 'package:accounting/utils/constants.dart';

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
        .where((t) => t.date.year == currentYear && t.date.month == currentMonth)
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
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
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
        _StatCard(label: '💰 ລາຍຮັບເດືອນນີ້', value: formatMoney(income), color: const Color(0xFF3FB950)),
        _StatCard(label: '💸 ລາຍຈ່າຍເດືອນນີ້', value: formatMoney(expense), color: const Color(0xFFF85149)),
        _StatCard(label: '📊 ສຸດທິເດືອນນີ້', value: formatMoneyWithSign(net), color: net >= 0 ? const Color(0xFF3FB950) : const Color(0xFFF85149)),
        _StatCard(label: '🏦 ຍອດຄົງເຫຼືອທັງໝົດ', value: formatMoneyWithSign(balance), color: const Color(0xFF58A6FF)),
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
                  child: Text('📊 ກຣາຟລາຍຮັບ-ລາຍຈ່າຍ 12 ເດືອນ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Row(
                  children: [
                    const Text('ປີ:', style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
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
                      ].map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                      onChanged: (value) => setState(() => _selectedYear = value!),
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
              children: const [
                _LegendDot(color: Color(0xFF3FB950), label: 'ລາຍຮັບ'),
                SizedBox(width: 16),
                _LegendDot(color: Color(0xFFF85149), label: 'ລາຍຈ່າຍ'),
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
                      if (t.date.year == _selectedYear && t.date.month == month) {
                        inc += t.income;
                        exp += t.expense;
                      }
                    }
                    final incHeight = maxValue > 0 ? (inc / maxValue * 120) : 0.0;
                    final expHeight = maxValue > 0 ? (exp / maxValue * 120) : 0.0;
                    return _BarColumn(month: month, inc: inc, exp: exp, incHeight: incHeight, expHeight: expHeight);
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

  Widget _buildDashboardGrid(List<Transaction> currentMonthTx, double overallBalance) {
    final recentTx = widget.transactions.reversed.take(8).toList();
    final total = currentMonthTx.fold(0.0, (s, t) => s + t.income + t.expense);
    final incPct = total > 0 ? (currentMonthTx.fold(0.0, (s, t) => s + t.income) / total * 100) : 0.0;
    final expPct = total > 0 ? (currentMonthTx.fold(0.0, (s, t) => s + t.expense) / total * 100) : 0.0;

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
                  child: Text('🕐 ລາຍການລ່າສຸດ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: recentTx.isEmpty
                      ? const Center(
                          child: Text('ຍັງບໍ່ມີລາຍການ', style: TextStyle(color: Color(0xFF8B949E))),
                        )
                      : Column(children: recentTx.map((t) => _RecentItemTile(transaction: t)).toList()),
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
                  child: Column(children: [
                    _RatioRow(label: 'ລາຍຮັບ', percent: incPct, color: const Color(0xFF3FB950)),
                    const SizedBox(height: 8),
                    _RatioRow(label: 'ລາຍຈ່າຍ', percent: expPct, color: const Color(0xFFF85149)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatRow(label: 'ທຸລະກຳທັງໝົດ', value: '${widget.transactions.length}'),
                      const SizedBox(height: 8),
                      _StatRow(label: 'ຍອດຄົງເຫຼືອທັງໝົດ', value: formatMoneyWithSign(overallBalance)),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

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
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
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
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
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

  const _BarColumn({required this.month, required this.inc, required this.exp, required this.incHeight, required this.expHeight});

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
              Container(width: 12, height: incHeight.clamp(2.0, 120.0), decoration: const BoxDecoration(color: Color(0xFF3FB950), borderRadius: BorderRadius.vertical(top: Radius.circular(3)))),
              const SizedBox(width: 2),
              Container(width: 12, height: expHeight.clamp(2.0, 120.0), decoration: const BoxDecoration(color: Color(0xFFF85149), borderRadius: BorderRadius.vertical(top: Radius.circular(3)))),
            ],
          ),
          const SizedBox(height: 4),
          Text(monthsShort[month - 1], style: const TextStyle(fontSize: 9, color: Color(0xFF484F58))),
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
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF21262D)))),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isIncome ? const Color(0xFF3FB950) : const Color(0xFFF85149))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.desc, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Text('${transaction.date.day}/${transaction.date.month}/${transaction.date.year}', style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: isIncome ? const Color(0xFF1A4D2E) : const Color(0xFF4D2A2A), borderRadius: BorderRadius.circular(4)),
                    child: Text(isIncome ? 'ຮັບ' : 'ຈ່າຍ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isIncome ? const Color(0xFF3FB950) : const Color(0xFFF85149))),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(formatMoney(isIncome ? transaction.income : transaction.expense), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isIncome ? const Color(0xFF3FB950) : const Color(0xFFF85149))),
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

  const _RatioRow({required this.label, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
            Text('${percent.toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: percent / 100, backgroundColor: const Color(0xFF1C2128), color: color),
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
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3))))),
      ],
    );
  }
}
