import 'package:flutter/material.dart';

import 'package:accounting/models/models.dart';
import 'package:accounting/utils/constants.dart';

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ສະຫຼຸບໄຕຣ໌ມາດ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('ສຽງ 4 ໄຕຣ໌ມາດ ຕໍ່ປີ', style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
          ])),
          DropdownButton<int>(
            value: _selectedYear,
            dropdownColor: const Color(0xFF1C2128),
            underline: const SizedBox(),
            items: [DateTime.now().year - 3, DateTime.now().year - 2, DateTime.now().year - 1, DateTime.now().year, DateTime.now().year + 1]
                .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                .toList(),
            onChanged: (value) => setState(() => _selectedYear = value!),
          ),
        ]),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: quarters.map((q) {
            final monthsList = q['months'] as List<int>;
            double inc = 0, exp = 0;
            for (var t in widget.transactions) {
              if (t.date.year == _selectedYear && monthsList.contains(t.date.month)) {
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: (q['color'] as Color).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(q['name'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: q['color'] as Color)),
                      ),
                      const SizedBox(width: 8),
                      Text(monthsList.map((m) => monthsShort[m - 1]).join(', '), style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
                    ]),
                    const SizedBox(height: 16),
                    _QRow(label: 'ລາຍຮັບ', value: formatMoney(inc), color: const Color(0xFF3FB950)),
                    const SizedBox(height: 6),
                    _QRow(label: 'ລາຍຈ່າຍ', value: formatMoney(exp), color: const Color(0xFFF85149)),
                    const Divider(height: 16),
                    _QRow(label: 'ສຸດທິ', value: formatMoneyWithSign(net), color: net >= 0 ? const Color(0xFF3FB950) : const Color(0xFFF85149)),
                  ]),
                ),
              ),
            );
          }).toList()),
        ),
      ]),
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
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    ]);
  }
}
