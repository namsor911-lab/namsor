// tax_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;

// ==================== DATA MODELS ====================

// 1. Employee Tax Model
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

// 2. VAT Model
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

// 3. Profit Tax Model
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

// ==================== STORAGE SERVICE ====================
class TaxStorageService {
  static const String _empKey = 'tax_records_v1';
  static const String _vatKey = 'vat_records_v1';
  static const String _profitKey = 'profit_records_v1';

  static List<TaxRecord> loadEmployees() {
    try {
      final json = html.window.localStorage[_empKey];
      if (json == null) return [];
      return (jsonDecode(json) as List).map((e) => TaxRecord.fromJson(e)).toList();
    } catch (_) { return []; }
  }
  static void saveEmployees(List<TaxRecord> r) => html.window.localStorage[_empKey] = jsonEncode(r.map((e) => e.toJson()).toList());

  static List<VatRecord> loadVat() {
    try {
      final json = html.window.localStorage[_vatKey];
      if (json == null) return [];
      return (jsonDecode(json) as List).map((e) => VatRecord.fromJson(e)).toList();
    } catch (_) { return []; }
  }
  static void saveVat(List<VatRecord> r) => html.window.localStorage[_vatKey] = jsonEncode(r.map((e) => e.toJson()).toList());

  static List<ProfitTaxRecord> loadProfit() {
    try {
      final json = html.window.localStorage[_profitKey];
      if (json == null) return [];
      return (jsonDecode(json) as List).map((e) => ProfitTaxRecord.fromJson(e)).toList();
    } catch (_) { return []; }
  }
  static void saveProfit(List<ProfitTaxRecord> r) => html.window.localStorage[_profitKey] = jsonEncode(r.map((e) => e.toJson()).toList());
}

// ==================== MAIN PAGE ====================
class TaxPage extends StatefulWidget {
  const TaxPage({super.key});

  @override
  State<TaxPage> createState() => _TaxPageState();
}

class _TaxPageState extends State<TaxPage> {
  int _selectedTaxMenu = 2; // Default ເລີ່ມຕົ້ນທີ່ ອາກອນລາຍໄດ້ພະນັກງານ
  final List<String> _taxMenus = [
    'VAT (ອາກອນມູນຄ່າເພີ່ມ)',
    'ອາກອນກຳໄລ',
    'ອາກອນລາຍໄດ້ພະນັກງານ',
    'ລາຍງານພາສີລວມ'
  ];

  // Data States
  final List<TaxRecord> _empRecords = [];
  final List<VatRecord> _vatRecords = [];
  final List<ProfitTaxRecord> _profitRecords = [];

  // Filter States
  int _selectedMonth = DateTime.now().month;
  String _searchQuery = '';
  final List<String> _months = ['ມັງກອນ', 'ກຸມພາ', 'ມີນາ', 'ເມສາ', 'ພຶດສະພາ', 'ມິຖຸນາ', 'ກໍລະກົດ', 'ສິງຫາ', 'ກັນຍາ', 'ຕຸລາ', 'ພະຈິກ', 'ທັນວາ'];

  @override
  void initState() {
    super.initState();
    _empRecords.addAll(TaxStorageService.loadEmployees());
    _vatRecords.addAll(TaxStorageService.loadVat());
    _profitRecords.addAll(TaxStorageService.loadProfit());
  }

  String _fmt(double v) => NumberFormat('#,###', 'lo').format(v);

  double _suggestTaxRate(double salary) {
    if (salary <= 1300000) return 0;
    if (salary <= 5000000) return 5;
    if (salary <= 10000000) return 10;
    if (salary <= 20000000) return 15;
    if (salary <= 40000000) return 20;
    return 24;
  }

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

  // ==================== MENU TABS ====================
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

  // ==================== VIEW 1: VAT (10%) ====================
  Widget _buildVatView() {
    final filteredVat = _vatRecords.where((r) =>
        r.invoiceNo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        r.detail.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    double totalBefore = filteredVat.fold(0, (s, r) => s + r.amountBeforeVat);
    double totalVat = filteredVat.fold(0, (s, r) => s + r.vatAmount);
    double totalAll = filteredVat.fold(0, (s, r) => s + r.totalAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('ລະບົບອາກອນມູນຄ່າເພີ່ມ (VAT)', 'ຄຳນວນ ແລະ ບັນທຶກລາຍການ VAT 10%', () => _showVatDialog()),
        const SizedBox(height: 16),
        _buildGridSummary([
          _CardData('ລາຍການທັງໝົດ', '${filteredVat.length} ໃບບິນ', Icons.receipt_outlined, const Color(0xFF58A6FF), const Color(0xFF1F3E6A)),
          _CardData('ມູນຄ່າກ່ອນ VAT', '${_fmt(totalBefore)} ₭', Icons.widgets_outlined, const Color(0xFF3FB950), const Color(0xFF1A4D2E)),
          _CardData('VAT 10% ລວມ', '${_fmt(totalVat)} ₭', Icons.percent_outlined, const Color(0xFFE06C6C), const Color(0xFF4D2A2A)),
          _CardData('ມູນຄ່າລວມທັງໝົດ', '${_fmt(totalAll)} ₭', Icons.analytics_outlined, const Color(0xFFD29922), const Color(0xFF4D3D10)),
        ]),
        const SizedBox(height: 16),
        _buildTableContainer(
          title: 'ລາຍການໃບບິນ VAT',
          child: filteredVat.isEmpty
              ? _buildEmptyState('ບໍ່ມີຂໍ້ມູນໃບບິນ VAT')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingTextStyle: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                    dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
                    columns: const [
                      DataColumn(label: Text('ເລກທີໃບບິນ')),
                      DataColumn(label: Text('ເນື້ອໃນລາຍການ')),
                      DataColumn(label: Text('ມູນຄ່າກ່ອນ VAT')),
                      DataColumn(label: Text('VAT (10%)')),
                      DataColumn(label: Text('ຍອດລວມ')),
                      DataColumn(label: Text('ຈັດການ')),
                    ],
                    rows: filteredVat.map((r) => DataRow(cells: [
                      DataCell(Text(r.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(r.detail)),
                      DataCell(Text(_fmt(r.amountBeforeVat), style: const TextStyle(color: Color(0xFF3FB950)))),
                      DataCell(Text(_fmt(r.vatAmount), style: const TextStyle(color: Color(0xFFE06C6C)))),
                      DataCell(Text(_fmt(r.totalAmount), style: const TextStyle(color: Color(0xFFD29922)))),
                      DataCell(IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        onPressed: () {
                          setState(() => _vatRecords.removeWhere((x) => x.id == r.id));
                          TaxStorageService.saveVat(_vatRecords);
                        },
                      )),
                    ])).toList(),
                  ),
                ),
        )
      ],
    );
  }

  void _showVatDialog() {
    final invCtrl = TextEditingController();
    final detCtrl = TextEditingController();
    final amtCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDlgState) {
      double amt = double.tryParse(amtCtrl.text.replaceAll(',', '')) ?? 0.0;
      double vatAmt = amt * 0.10;
      double totalAmt = amt + vatAmt;

      return AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('ເພີ່ມລາຍການ VAT', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(invCtrl, 'ເລກທີໃບບິນ (Invoice No.)', Icons.numbers),
                const SizedBox(height: 12),
                _buildTextField(detCtrl, 'ເນື້ອໃນລາຍການ', Icons.description_outlined),
                const SizedBox(height: 12),
                _buildTextField(amtCtrl, 'ມູນຄ່າກ່ອນອາກອນ (₭)', Icons.monetization_on_outlined, isNumber: true, onChanged: (v) => setDlgState((){})),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('VAT (10%):', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text('+ ${_fmt(vatAmt)} ₭', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ]),
                    const Divider(color: Color(0xFF30363D)),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('ຍອດລວມສຸທິ:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text('${_fmt(totalAmt)} ₭', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                    ]),
                  ]),
                )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ຍົກເລີກ', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (invCtrl.text.isEmpty || amt <= 0) return;
              setState(() {
                _vatRecords.add(VatRecord(id: DateTime.now().toString(), invoiceNo: invCtrl.text, detail: detCtrl.text, amountBeforeVat: amt));
              });
              TaxStorageService.saveVat(_vatRecords);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E4343)),
            child: const Text('ບັນທຶກ', style: TextStyle(color: Colors.white)),
          )
        ],
      );
    }));
  }

  // ==================== VIEW 2: PROFIT TAX (20%) ====================
  Widget _buildProfitTaxView() {
    final filteredProfit = _profitRecords.where((r) => r.periodTitle.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    double totalRev = filteredProfit.fold(0, (s, r) => s + r.totalRevenue);
    double totalExp = filteredProfit.fold(0, (s, r) => s + r.totalExpense);
    double totalProfit = totalRev - totalExp;
    double totalTax = filteredProfit.fold(0, (s, r) => s + r.taxAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('ອາກອນກຳໄລວິສາຫະກິດ', 'ຄຳນວນອາກອນກຳໄລປະຈຳງວດ 20%', () => _showProfitDialog()),
        const SizedBox(height: 16),
        _buildGridSummary([
          _CardData('ລາຍຮັບສະສົມ', '${_fmt(totalRev)} ₭', Icons.arrow_upward, const Color(0xFF3FB950), const Color(0xFF1A4D2E)),
          _CardData('ລາຍຈ່າຍສະສົມ', '${_fmt(totalExp)} ₭', Icons.arrow_downward, const Color(0xFFE06C6C), const Color(0xFF4D2A2A)),
          _CardData('ກຳໄລສຸດທິລວມ', '${_fmt(totalProfit)} ₭', Icons.monetization_on_outlined, const Color(0xFFD29922), const Color(0xFF4D3D10)),
          _CardData('ອາກອນຕ້ອງເສຍ', '${_fmt(totalTax)} ₭', Icons.account_balance, const Color(0xFF58A6FF), const Color(0xFF1F3E6A)),
        ]),
        const SizedBox(height: 16),
        _buildTableContainer(
          title: 'ປະຫວັດການຄຳນວນອາກອນກຳໄລ',
          child: filteredProfit.isEmpty
              ? _buildEmptyState('ບໍ່ມີຂໍ້ມູນອາກອນກຳໄລ')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingTextStyle: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                    dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
                    columns: const [
                      DataColumn(label: Text('ງວດ/ໄລຍະເວລາ')),
                      DataColumn(label: Text('ລາຍຮັບ')),
                      DataColumn(label: Text('ລາຍຈ່າຍ')),
                      DataColumn(label: Text('ກຳໄລສຸດທິ')),
                      DataColumn(label: Text('ອາກອນກຳໄລ (20%)')),
                      DataColumn(label: Text('ຈັດການ')),
                    ],
                    rows: filteredProfit.map((r) => DataRow(cells: [
                      DataCell(Text(r.periodTitle, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(_fmt(r.totalRevenue))),
                      DataCell(Text(_fmt(r.totalExpense))),
                      DataCell(Text(_fmt(r.netProfit), style: TextStyle(color: r.netProfit > 0 ? Colors.green : Colors.redAccent))),
                      DataCell(Text(_fmt(r.taxAmount), style: const TextStyle(color: Color(0xFFE06C6C), fontWeight: FontWeight.bold))),
                      DataCell(IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        onPressed: () {
                          setState(() => _profitRecords.removeWhere((x) => x.id == r.id));
                          TaxStorageService.saveProfit(_profitRecords);
                        },
                      )),
                    ])).toList(),
                  ),
                ),
        )
      ],
    );
  }

  void _showProfitDialog() {
    final titleCtrl = TextEditingController();
    final revCtrl = TextEditingController();
    final expCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDlgState) {
      double rev = double.tryParse(revCtrl.text.replaceAll(',', '')) ?? 0.0;
      double exp = double.tryParse(expCtrl.text.replaceAll(',', '')) ?? 0.0;
      double profit = rev - exp;
      double tax = profit > 0 ? profit * 0.20 : 0.0;

      return AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('ຄຳນວນອາກອນກຳໄລ', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(titleCtrl, 'ໄລຍະເວລາ (ເຊັ່ນ: ໄຕມາດ 1)', Icons.calendar_month),
                const SizedBox(height: 12),
                _buildTextField(revCtrl, 'ລາຍຮັບທັງໝົດ (₭)', Icons.trending_up, isNumber: true, onChanged: (v) => setDlgState((){})),
                const SizedBox(height: 12),
                _buildTextField(expCtrl, 'ລາຍຈ່າຍທັງໝົດ (₭)', Icons.trending_down, isNumber: true, onChanged: (v) => setDlgState((){})),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('ກຳໄລ/ຂາດທຶນ:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text('${_fmt(profit)} ₭', style: TextStyle(color: profit > 0 ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold)),
                    ]),
                    const Divider(color: Color(0xFF30363D)),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('ອາກອນກຳໄລ (20%):', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text('${_fmt(tax)} ₭', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ]),
                  ]),
                )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ຍົກເລີກ', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.isEmpty) return;
              setState(() {
                _profitRecords.add(ProfitTaxRecord(id: DateTime.now().toString(), periodTitle: titleCtrl.text, totalRevenue: rev, totalExpense: exp));
              });
              TaxStorageService.saveProfit(_profitRecords);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E4343)),
            child: const Text('ບັນທຶກ', style: TextStyle(color: Colors.white)),
          )
        ],
      );
    }));
  }

  // ==================== VIEW 3: EMPLOYEE TAX ====================
  Widget _buildEmployeeTaxView() {
    final filteredEmp = _empRecords.where((r) =>
        r.employeeName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        r.position.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    double totalGross = filteredEmp.fold(0, (s, r) => s + r.grossSalary);
    double totalTax = filteredEmp.fold(0, (s, r) => s + r.taxAmount);
    double totalNet = filteredEmp.fold(0, (s, r) => s + r.netSalary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('ອາກອນລາຍໄດ້ພະນັກງານ', 'ຄຳນວນພາສີລາຍໄດ້ບຸກຄົນຕາມອັດຕາກ້າວໜ້າ', () => _showEmpDialog(), isEmployee: true),
        const SizedBox(height: 16),
        _buildGridSummary([
          _CardData('ພະນັກງານທັງໝົດ', '${filteredEmp.length} ຄົນ', Icons.people_outline, const Color(0xFF58A6FF), const Color(0xFF1F3E6A)),
          _CardData('ເງິນເດືອນລວມ', '${_fmt(totalGross)} ₭', Icons.account_balance_wallet_outlined, const Color(0xFF3FB950), const Color(0xFF1A4D2E)),
          _CardData('ອາກອນລວມ', '${_fmt(totalTax)} ₭', Icons.receipt_long_outlined, const Color(0xFFE06C6C), const Color(0xFF4D2A2A)),
          _CardData('ເງິນສຸດທິລວມ', '${_fmt(totalNet)} ₭', Icons.payments_outlined, const Color(0xFFD29922), const Color(0xFF4D3D10)),
        ]),
        const SizedBox(height: 16),
        _buildTableContainer(
          title: 'ຕາຕະລາງພະນັກງານ',
          child: filteredEmp.isEmpty
              ? _buildEmptyState('ຍັງບໍ່ມີຂໍ້ມູນພະນັກງານ')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingTextStyle: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                    dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
                    columns: const [
                      DataColumn(label: Text('ລ/ດ')),
                      DataColumn(label: Text('ชื່ພະນັກງານ')),
                      DataColumn(label: Text('ຕຳແໜ່ງ')),
                      DataColumn(label: Text('ເງິນເດືອນ (₭)')),
                      DataColumn(label: Text('ອັດຕາ (%)')),
                      DataColumn(label: Text('ອາກອນ')),
                      DataColumn(label: Text('ເງິນສຸດທິ')),
                      DataColumn(label: Text('ຈັດການ')),
                    ],
                    rows: List.generate(filteredEmp.length, (i) {
                      final r = filteredEmp[i];
                      return DataRow(cells: [
                        DataCell(Text('${i + 1}', style: const TextStyle(color: Colors.grey))),
                        DataCell(Text(r.employeeName, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(r.position, style: const TextStyle(color: Colors.grey))),
                        DataCell(Text(_fmt(r.grossSalary), style: const TextStyle(color: Colors.green))),
                        DataCell(Text('${r.taxRate}%')),
                        DataCell(Text(_fmt(r.taxAmount), style: const TextStyle(color: Colors.redAccent))),
                        DataCell(Text(_fmt(r.netSalary), style: const TextStyle(color: Colors.amber))),
                        DataCell(Row(
                          children: [
                            IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue), onPressed: () => _showEmpDialog(record: r)),
                            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), onPressed: () {
                              setState(() => _empRecords.removeWhere((x) => x.id == r.id));
                              TaxStorageService.saveEmployees(_empRecords);
                            }),
                          ],
                        )),
                      ]);
                    }),
                  ),
                ),
        )
      ],
    );
  }

  void _showEmpDialog({TaxRecord? record}) {
    final isEdit = record != null;
    final nameCtrl = TextEditingController(text: record?.employeeName ?? '');
    final posCtrl = TextEditingController(text: record?.position ?? '');
    final salCtrl = TextEditingController(text: record != null ? record.grossSalary.toStringAsFixed(0) : '');
    double taxRate = record?.taxRate ?? 5.0;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDlgState) {
      final salary = double.tryParse(salCtrl.text.replaceAll(',', '')) ?? 0;
      final suggested = _suggestTaxRate(salary);

      return AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(isEdit ? 'ແກ້ໄຂຂໍ້ມູນ' : 'ເພີ່ມພະນັກງານ', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameCtrl, 'ຊື່ພະນັກງານ', Icons.person_outline),
                const SizedBox(height: 12),
                _buildTextField(posCtrl, 'ຕຳແໜ່ງ', Icons.work_outline),
                const SizedBox(height: 12),
                _buildTextField(salCtrl, 'ເງິນເດືອນ (₭)', Icons.monetization_on_outlined, isNumber: true, onChanged: (_) {
                  final s = double.tryParse(salCtrl.text.replaceAll(',', '')) ?? 0;
                  setDlgState(() => taxRate = _suggestTaxRate(s));
                }),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('ອັດຕາອາກອນ:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Text('$taxRate%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ]),
                Slider(
                  value: taxRate, min: 0, max: 25, divisions: 25,
                  activeColor: Colors.redAccent, inactiveColor: const Color(0xFF30363D),
                  onChanged: (v) => setDlgState(() => taxRate = v),
                ),
                Text('ແນະນຳ: $suggested%', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ຍົກເລີກ', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final sal = double.tryParse(salCtrl.text.replaceAll(',', '')) ?? 0;
              if (nameCtrl.text.isEmpty || sal <= 0) return;

              setState(() {
                if (isEdit) {
                  record.employeeName = nameCtrl.text;
                  record.position = posCtrl.text;
                  record.grossSalary = sal;
                  record.taxRate = taxRate;
                } else {
                  _empRecords.add(TaxRecord(id: DateTime.now().toString(), employeeName: nameCtrl.text, position: posCtrl.text, grossSalary: sal, taxRate: taxRate));
                }
              });
              TaxStorageService.saveEmployees(_empRecords);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E4343)),
            child: const Text('ບັນທຶກ', style: TextStyle(color: Colors.white)),
          )
        ],
      );
    }));
  }

  // ==================== VIEW 4: REPORT DASHBOARD ====================
  Widget _buildTaxReportView() {
    double totalEmpTax = _empRecords.fold(0, (s, r) => s + r.taxAmount);
    double totalVat = _vatRecords.fold(0, (s, r) => s + r.vatAmount);
    double totalProfitTax = _profitRecords.fold(0, (s, r) => s + r.taxAmount);
    double grandTotalTax = totalEmpTax + totalVat + totalProfitTax;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border.all(color: const Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 ບົດສະຫຼຸບລາຍງານພາສີ-ອາກອນ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const Text('ລວບລວມຂໍ້ມູນອັດຕະໂນມັດຈາກທຸກລະບົບພາສີ', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 30),
          _buildReportRow('1. ອາກອນມູນຄ່າເພີ່ມ (VAT)', totalVat, const Color(0xFF58A6FF)),
          _buildReportRow('2. ອາກອນກຳໄລວິສາຫະກິດ', totalProfitTax, const Color(0xFF3FB950)),
          _buildReportRow('3. ອາກອນລາຍໄດ້ພະນັກງານ', totalEmpTax, const Color(0xFFD29922)),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF30363D), thickness: 1.5),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ລວມພາສີທັງໝົດທີ່ຕ້ອງຈ່າຍ:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('${_fmt(grandTotalTax)} ₭', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(String title, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          Text('${_fmt(value)} ₭', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ==================== UI HELPERS ====================
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF30363D)), borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.blueAccent), borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String sub, VoidCallback onAdd, {bool isEmployee = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF161B22), border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('ເພີ່ມຂໍ້ມູນ', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E4343), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (isEmployee) ...[
                DropdownButton<int>(
                  value: _selectedMonth,
                  dropdownColor: const Color(0xFF161B22),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_months[i]))),
                  onChanged: (v) => setState(() => _selectedMonth = v!),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ຄົ້ນຫາ...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildGridSummary(List<_CardData> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 2 : 1);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth > 500 ? 2.8 : 3.5,
          children: items.map((d) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF161B22), border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: d.bgColor, borderRadius: BorderRadius.circular(6)),
                  child: Icon(d.icon, size: 20, color: d.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(d.label, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(d.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: d.color), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                )
              ],
            ),
          )).toList(),
        );
      }
    );
  }

  Widget _buildTableContainer({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFF161B22), border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const Divider(color: Color(0xFF30363D), height: 1),
          child,
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.folder_open, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _CardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  _CardData(this.label, this.value, this.icon, this.color, this.bgColor);
}