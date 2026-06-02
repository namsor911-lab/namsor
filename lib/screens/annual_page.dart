import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import 'package:accounting/models/models.dart';
import 'package:accounting/utils/constants.dart';

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ສະຫຼຸບລາຍປີ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('ຂໍ້ມູນລາຍຮັບ-ລາຍຈ່າຍ 12 ເດືອນ', style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
          ])),
          IconButton(icon: const Icon(Icons.download, size: 18), onPressed: _exportAnnualCSV, tooltip: 'Export CSV'),
          DropdownButton<int>(
            value: _selectedYear,
            dropdownColor: const Color(0xFF1C2128),
            underline: const SizedBox(),
            items: [DateTime.now().year - 3, DateTime.now().year - 2, DateTime.now().year - 1, DateTime.now().year, DateTime.now().year + 1]
                .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                .toList(),
            onChanged: (v) => setState(() => _selectedYear = v!),
          ),
        ]),
        const SizedBox(height: 20),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _SummaryItem(label: 'ລາຍຮັບລວມ', value: formatMoney(totInc), color: const Color(0xFF3FB950)),
          _SummaryItem(label: 'ລາຍຈ່າຍລວມ', value: formatMoney(totExp), color: const Color(0xFFF85149)),
          _SummaryItem(label: 'ສຸດທິລວມ', value: formatMoneyWithSign(totInc - totExp), color: (totInc - totExp) >= 0 ? const Color(0xFF3FB950) : const Color(0xFFF85149)),
        ]))),
        const SizedBox(height: 16),
        Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [
          DataColumn(label: Text('ເດືອນ')),
          DataColumn(label: Text('ລາຍຮັບ')),
          DataColumn(label: Text('ລາຍຈ່າຍ')),
          DataColumn(label: Text('ສຸດທິ')),
        ], rows: List.generate(12, (i) {
          final d = monthlyData[i];
          final net = (d['inc'] ?? 0) - (d['exp'] ?? 0);
          return DataRow(cells: [
            DataCell(Text(months[i])),
            DataCell(Text(formatMoney(d['inc'] ?? 0), style: const TextStyle(color: Color(0xFF3FB950)))),
            DataCell(Text(formatMoney(d['exp'] ?? 0), style: const TextStyle(color: Color(0xFFF85149)))),
            DataCell(Text(formatMoneyWithSign(net), style: TextStyle(color: net >= 0 ? const Color(0xFF3FB950) : const Color(0xFFF85149)))),
          ]);
        })))),
      ]),
    );
  }

  void _exportAnnualCSV() {
    final monthlyData = _getMonthlyData();
    double cumul = getOpeningBalance(widget.transactions, _selectedYear, 1);
    final lines = ['\uFEFFເດືອນ,ລາຍຮັບ(₭),ລາຍຈ່າຍ(₭),ສຸດທິ(₭),ຍອດໂກຍ(₭)'];
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

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}
