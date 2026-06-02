import 'package:flutter/material.dart';

import 'package:accounting/models/models.dart';
import 'package:accounting/services/services.dart';
import 'package:accounting/utils/constants.dart';

class TaxPage extends StatefulWidget {
  const TaxPage({super.key});

  @override
  State<TaxPage> createState() => _TaxPageState();
}

class _TaxPageState extends State<TaxPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('ການນິຍາມພາສີ'),
        backgroundColor: const Color(0xFF161B22),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'ພາສີພະນັກງານ'), Tab(text: 'VAT'), Tab(text: 'ພາສີຂາຍ')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEmployeeTax(),
          _buildVatTax(),
          _buildProfitTax(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddRecord,
        backgroundColor: const Color(0xFF238636),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _onAddRecord() {
    if (_tabController.index == 0) {
      _showEmployeeDialog();
    } else if (_tabController.index == 1) {
      _showVatDialog();
    } else {
      _showProfitDialog();
    }
  }

  Widget _buildEmployeeTax() {
    return StreamBuilder<List<TaxRecord>>(
      stream: TaxRecordService.employeeStream(),
      builder: (context, snap) {
        final records = snap.data ?? [];
        if (records.isEmpty) {
          return const Center(child: Text('ຍັງບໍ່ມີຂໍ້ມູນພະນັກງານ', style: TextStyle(color: Color(0xFF8B949E))));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return Card(
              color: const Color(0xFF161B22),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(record.employeeName, style: const TextStyle(color: Colors.white)),
                subtitle: Text('${record.position} • ${formatMoneyWithCurrency(record.grossSalary)}', style: const TextStyle(color: Color(0xFF8B949E))),
                trailing: Text(formatMoneyWithCurrency(record.taxAmount), style: const TextStyle(color: Color(0xFFF85149), fontWeight: FontWeight.w700)),
                onTap: () => _showEmployeeDialog(record: record),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVatTax() {
    return StreamBuilder<List<VatRecord>>(
      stream: TaxRecordService.vatStream(),
      builder: (context, snap) {
        final records = snap.data ?? [];
        if (records.isEmpty) {
          return const Center(child: Text('ຍັງບໍ່ມີຂໍ້ມູນ VAT', style: TextStyle(color: Color(0xFF8B949E))));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return Card(
              color: const Color(0xFF161B22),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(record.invoiceNo, style: const TextStyle(color: Colors.white)),
                subtitle: Text('${record.detail} • ${formatMoneyWithCurrency(record.amountBeforeVat)}', style: const TextStyle(color: Color(0xFF8B949E))),
                trailing: Text('${record.vatRate.toStringAsFixed(0)}%', style: const TextStyle(color: Color(0xFF58A6FF), fontWeight: FontWeight.w700)),
                onTap: () => _showVatDialog(record: record),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfitTax() {
    return StreamBuilder<List<ProfitTaxRecord>>(
      stream: TaxRecordService.profitStream(),
      builder: (context, snap) {
        final records = snap.data ?? [];
        if (records.isEmpty) {
          return const Center(child: Text('ຍັງບໍ່ມີຂໍ້ມູນພາສີຂາຍ', style: TextStyle(color: Color(0xFF8B949E))));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final payable = record.taxAmount;
            return Card(
              color: const Color(0xFF161B22),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(record.periodTitle, style: const TextStyle(color: Colors.white)),
                subtitle: Text('${formatMoneyWithCurrency(record.totalRevenue)} • ${record.periodTitle}', style: const TextStyle(color: Color(0xFF8B949E))),
                trailing: Text(formatMoneyWithCurrency(payable), style: const TextStyle(color: Color(0xFFF85149), fontWeight: FontWeight.w700)),
                onTap: () => _showProfitDialog(record: record),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEmployeeDialog({TaxRecord? record}) async {
    final nameCtrl = TextEditingController(text: record?.employeeName ?? '');
    final positionCtrl = TextEditingController(text: record?.position ?? '');
    final salaryCtrl = TextEditingController(text: record?.grossSalary.toStringAsFixed(0) ?? '0');
    final rateCtrl = TextEditingController(text: record?.taxRate.toStringAsFixed(0) ?? '0');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(record == null ? 'ເພີ່ມພະນັກງານ' : 'ແກ້ໄຂພະນັກງານ', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ຊື່', labelStyle: TextStyle(color: Color(0xFF8B949E))), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: positionCtrl, decoration: const InputDecoration(labelText: 'ຕຳແໜ່ງ', labelStyle: TextStyle(color: Color(0xFF8B949E))), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: salaryCtrl, decoration: const InputDecoration(labelText: 'ເງິນເດືອນ', labelStyle: TextStyle(color: Color(0xFF8B949E))), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: rateCtrl, decoration: const InputDecoration(labelText: 'ອັດຕາພາສີ', labelStyle: TextStyle(color: Color(0xFF8B949E))), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ຍົກເລີກ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final position = positionCtrl.text.trim();
              final salary = double.tryParse(salaryCtrl.text) ?? 0;
              final rate = double.tryParse(rateCtrl.text) ?? 0;
              if (name.isEmpty || position.isEmpty || salary <= 0) {
                return;
              }
              final newRecord = TaxRecord(
                id: record?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                employeeName: name,
                position: position,
                grossSalary: salary,
                taxRate: rate,
              );
              if (record == null) {
                TaxRecordService.addEmployee(newRecord);
              } else {
                TaxRecordService.updateEmployee(newRecord);
              }
              Navigator.pop(context);
            },
            child: const Text('ບັນທຶກ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showVatDialog({VatRecord? record}) async {
    final invoiceCtrl = TextEditingController(text: record?.invoiceNo ?? '');
    final detailCtrl = TextEditingController(text: record?.detail ?? '');
    final amountCtrl = TextEditingController(text: record?.amountBeforeVat.toStringAsFixed(0) ?? '0');
    final rateCtrl = TextEditingController(text: record?.vatRate.toStringAsFixed(0) ?? '0');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(record == null ? 'ເພີ່ມ VAT' : 'ແກ້ໄຂ VAT', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: invoiceCtrl, decoration: const InputDecoration(labelText: 'ເລກທີ່ໃບບິນ', labelStyle: TextStyle(color: Color(0xFF8B949E))), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: detailCtrl, decoration: const InputDecoration(labelText: 'ລາຍລະອຽດ', labelStyle: TextStyle(color: Color(0xFF8B949E))), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'ຈຳນວນກ່ອນ VAT', labelStyle: TextStyle(color: Color(0xFF8B949E))), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: rateCtrl, decoration: const InputDecoration(labelText: 'ອັດຕາ VAT', labelStyle: TextStyle(color: Color(0xFF8B949E))), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ຍົກເລີກ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
            onPressed: () {
              final invoice = invoiceCtrl.text.trim();
              final detail = detailCtrl.text.trim();
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              final rate = double.tryParse(rateCtrl.text) ?? 0;
              if (invoice.isEmpty || detail.isEmpty || amount <= 0) {
                return;
              }
              final newRecord = VatRecord(
                id: record?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                invoiceNo: invoice,
                detail: detail,
                amountBeforeVat: amount,
                vatRate: rate,
              );
              if (record == null) {
                TaxRecordService.addVat(newRecord);
              } else {
                TaxRecordService.updateVat(newRecord);
              }
              Navigator.pop(context);
            },
            child: const Text('ບັນທຶກ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showProfitDialog({ProfitTaxRecord? record}) async {
    final periodCtrl = TextEditingController(text: record?.periodTitle ?? '');
    final revenueCtrl = TextEditingController(text: record?.totalRevenue.toStringAsFixed(0) ?? '0');
    final expenseCtrl = TextEditingController(text: record?.totalExpense.toStringAsFixed(0) ?? '0');
    final rateCtrl = TextEditingController(text: record?.taxRate.toStringAsFixed(0) ?? '0');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(record == null ? 'ເພີ່ມ ພາສີຂາຍ' : 'ແກ້ໄຂ ພາສີຂາຍ', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: periodCtrl, decoration: const InputDecoration(labelText: 'ໄລຍະເວລາ', labelStyle: TextStyle(color: Color(0xFF8B949E))), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: revenueCtrl, decoration: const InputDecoration(labelText: 'ລາຍຮັບທັງໝົດ', labelStyle: TextStyle(color: Color(0xFF8B949E))), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: expenseCtrl, decoration: const InputDecoration(labelText: 'ລາຍຈ່າຍທັງໝົດ', labelStyle: TextStyle(color: Color(0xFF8B949E))), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: rateCtrl, decoration: const InputDecoration(labelText: 'ອັດຕາພາສີ', labelStyle: TextStyle(color: Color(0xFF8B949E))), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ຍົກເລີກ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
            onPressed: () {
              final period = periodCtrl.text.trim();
              final revenue = double.tryParse(revenueCtrl.text) ?? 0;
              final expense = double.tryParse(expenseCtrl.text) ?? 0;
              final rate = double.tryParse(rateCtrl.text) ?? 0;
              if (period.isEmpty || revenue <= 0) {
                return;
              }
              final newRecord = ProfitTaxRecord(
                id: record?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                periodTitle: period,
                totalRevenue: revenue,
                totalExpense: expense,
                taxRate: rate,
              );
              if (record == null) {
                TaxRecordService.addProfit(newRecord);
              } else {
                TaxRecordService.updateProfit(newRecord);
              }
              Navigator.pop(context);
            },
            child: const Text('ບັນທຶກ'),
          ),
        ],
      ),
    );
  }
}
