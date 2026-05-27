// shopping_page.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

// ==================== DATA MODEL ຊື້ເຄື່ອງ ====================
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

// ==================== DATA MODEL ແຜນຊື້ເຄື່ອງ ====================
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

// ຕົວປ່ຽນ Global ສຳລັບເກັບຂໍ້ມູນແຜນຊື້ເຄື່ອງ ເພື່ອບໍ່ໃຫ້ຫາຍເວລາປ່ຽນໜ້າ
final List<PlanItem> globalPlanItems = [];

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

  // ===== ຄຳນວນສະຫຼຸບສຳລັບກຣາຟ =====
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

  // ==================== LEFT PANEL ====================
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
                const SizedBox(height: 14),
                const Divider(color: Color(0xFF21262D), height: 1),
                const SizedBox(height: 12),
                _buildFilterBar(),
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
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Column(
                        children: [
                          const Text('🧺', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text(
                            _items.isEmpty
                                ? 'ຍັງບໍ່ມີລາຍການໃນລະບົບ'
                                : 'ບໍ່ພົບລາຍການໃນເດືອນ ${months[_selectedMonth - 1]}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8B949E),
                            ),
                          ),
                          if (_items.isEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'ກົດ "ເພີ່ມລາຍການ" ເພື່ອເລີ່ມຕົ້ນ',
                              style: TextStyle(fontSize: 12, color: Color(0xFF484F58)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFF21262D)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${filteredItems.length} ລາຍການ',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8B949E),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A4D2E),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'ລວມ: ',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                                  ),
                                  Text(
                                    _formatMoney(_getGrandTotal(filteredItems)),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF3FB950),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildDataTable(filteredItems),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ==================== RIGHT PANEL ====================
  Widget _buildRightPanel({
    required List<ShoppingItem> filteredItems,
    required double grandTotal,
    required List<ShoppingItem> topItems,
    required List<_MonthSummary> monthlyTotals,
    required double maxMonthly,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
      child: Column(
        children: [
          _SummaryStatCard(
            month: months[_selectedMonth - 1],
            year: _selectedYear,
            count: filteredItems.length,
            grandTotal: grandTotal,
            formatMoney: _formatMoney,
          ),
          const SizedBox(height: 14),
          _MonthlyBarChart(
            monthlyTotals: monthlyTotals,
            maxMonthly: maxMonthly,
            selectedMonth: _selectedMonth,
            formatMoney: _formatMoney,
          ),
          const SizedBox(height: 14),
          _TopItemsPanel(
            topItems: topItems,
            grandTotal: grandTotal,
            formatMoney: _formatMoney,
          ),
        ],
      ),
    );
  }

  // ==================== FILTER BAR ====================
  Widget _buildFilterBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;

        final dropdowns = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<int>(
              value: _selectedMonth,
              dropdownColor: const Color(0xFF1C2128),
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 13, color: Color(0xFFE6EDF3)),
              items: List.generate(
                12,
                (i) => DropdownMenuItem(value: i + 1, child: Text(months[i])),
              ),
              onChanged: (value) => setState(() => _selectedMonth = value!),
            ),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _selectedYear,
              dropdownColor: const Color(0xFF1C2128),
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 13, color: Color(0xFFE6EDF3)),
              items: [
                DateTime.now().year - 3,
                DateTime.now().year - 2,
                DateTime.now().year - 1,
                DateTime.now().year,
                DateTime.now().year + 1,
              ]
                  .map((y) =>
                      DropdownMenuItem(value: y, child: Text(y.toString())))
                  .toList(),
              onChanged: (value) => setState(() => _selectedYear = value!),
            ),
          ],
        );

        final searchField = TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'ຄົ້ນຫາລາຍການ...',
            hintStyle: TextStyle(fontSize: 12),
            prefixIcon: Icon(Icons.search, size: 14),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dropdowns,
              const SizedBox(height: 8),
              searchField,
            ],
          );
        }
        return Row(
          children: [
            dropdowns,
            const SizedBox(width: 12),
            Expanded(child: searchField),
          ],
        );
      },
    );
  }

  // ==================== DATA TABLE ====================
  Widget _buildDataTable(List<ShoppingItem> items) {
    return DataTable(
      columnSpacing: 14,
      headingRowColor: WidgetStateProperty.all(const Color(0xFF0D1117)),
      headingTextStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8B949E),
        letterSpacing: 0.4,
      ),
      dataTextStyle: const TextStyle(fontSize: 12, color: Color(0xFFE6EDF3)),
      dividerThickness: 0.5,
      columns: const [
        DataColumn(label: Text('ລ/ດ')),
        DataColumn(label: Text('ວ/ດ/ປ')),
        DataColumn(label: Text('ລາຍການຊື້')),
        DataColumn(label: Text('ຈຳນວນ')),
        DataColumn(label: Text('ຫົວໜ່ວຍ')),
        DataColumn(label: Text('ລາຄາ/ໜ່ວຍ')),
        DataColumn(label: Text('ຜົນລວມ')),
        DataColumn(label: Text('ໃບບິນ')),
        DataColumn(label: Text('ໝາຍເຫດ')),
        DataColumn(label: Text('ຈັດການ')),
      ],
      rows: List.generate(items.length, (index) {
        final item = items[index];
        return DataRow(
          cells: [
            DataCell(Text(
              '${index + 1}',
              style: const TextStyle(color: Color(0xFF484F58), fontSize: 11),
            )),
            DataCell(Text(
              '${item.date.day}/${item.date.month}/${item.date.year}',
              style: const TextStyle(
                  fontFamily: 'IBM Plex Mono', fontSize: 11, color: Color(0xFF8B949E)),
            )),
            DataCell(Text(
              item.itemName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            )),
            DataCell(Text(
              item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2),
              style: const TextStyle(color: Color(0xFF58A6FF)),
            )),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2128),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Text(item.unit, style: const TextStyle(fontSize: 11)),
            )),
            DataCell(Text(
              _formatMoney(item.unitPrice),
              style: const TextStyle(color: Color(0xFFE6EDF3)),
            )),
            DataCell(Text(
              _formatMoney(item.totalPrice),
              style: const TextStyle(
                color: Color(0xFF3FB950),
                fontWeight: FontWeight.w700,
              ),
            )),
            DataCell(
              item.receipts.isEmpty
                  ? const Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF8B949E)))
                  : InkWell(
                      onTap: () => _showReceiptViewer(item.receipts),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long, size: 14, color: Color(0xFF58A6FF)),
                            const SizedBox(width: 4),
                            Text(
                              '${item.receipts.length} ໃບ',
                              style: const TextStyle(
                                fontSize: 11, 
                                color: Color(0xFF58A6FF), 
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF58A6FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            DataCell(Text(
              item.note.isEmpty ? '—' : item.note,
              style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
            )),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF58A6FF)),
                  onPressed: () => _showShoppingDialog(item: item),
                  tooltip: 'ແກ້ໄຂ',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFF85149)),
                  onPressed: () => _deleteItem(item.id),
                  tooltip: 'ລຶບ',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
              ],
            )),
          ],
        );
      }),
    );
  }

  // ==================== VIEWER: ສະແດງຮູບພາບໃບບິນ ====================
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
                      child: kIsWeb
                          ? Image.network(
                              path,
                              width: 250,
                              height: 350,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
                            )
                          : Image.file(
                              File(path),
                              width: 250,
                              height: 350,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
                            ),
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

  // Widget ສຳລັບສະແດງຜົນຕອນຮູບ error
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

  // ==================== DIALOG ບັນທຶກ ====================
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
                      color: isEdit
                          ? const Color(0xFF1F4E79)
                          : const Color(0xFF1A4D2E),
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
                    isEdit ? 'ແກ້ໄຂລາຍການຊື້' : 'ເພີ່ມລາຍການຊື້ໃໝ່',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                              const Icon(Icons.calendar_today,
                                  size: 14, color: Color(0xFF8B949E)),
                              const SizedBox(width: 8),
                              const Text(
                                'ວັນທີ: ',
                                style: TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                              ),
                              Text(
                                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              const Icon(Icons.chevron_right,
                                  size: 16, color: Color(0xFF484F58)),
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
                              decoration:
                                  const InputDecoration(labelText: 'ຫົວໜ່ວຍ (ອັນ, ຊຸດ...)'),
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
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF484F58),
                                  ),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () {
                    final name = itemController.text.trim();
                    final qty = double.tryParse(qtyController.text) ?? 0;
                    final price = double.tryParse(priceController.text) ?? 0;
                    final unit = unitController.text.trim();

                    if (name.isEmpty || qty <= 0 || price <= 0 || unit.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('ກະລຸນາປ້ອນຂໍ້ມູນໃຫ້ຄົບ ແລະ ຖືກຕ້ອງ')),
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

// ==================== ໜ້າຈໍແຜນຊື້ເຄື່ອງ (ໃໝ່) ====================
class ShoppingPlanPage extends StatefulWidget {
  const ShoppingPlanPage({super.key});

  @override
  State<ShoppingPlanPage> createState() => _ShoppingPlanPageState();
}

class _ShoppingPlanPageState extends State<ShoppingPlanPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // ໃຊ້ globalPlanItems ທີ່ຢູ່ທາງນອກເພື່ອບໍ່ໃຫ້ຂໍ້ມູນຫາຍເວລາປ່ຽນໜ້າ
    final filteredItems = globalPlanItems.where((item) {
      return item.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             item.note.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // ພື້ນຫຼັງສີດຳເຂັ້ມ
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('ແຜນຊື້ເຄື່ອງ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE6EDF3))),
        iconTheme: const IconThemeData(color: Color(0xFFE6EDF3)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFF30363D), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ກ່ອງເຄື່ອງມື ແລະ ຄົ້ນຫາ
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
            // ກ່ອງຕາຕະລາງແຜນຊື້
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
                                  DataCell(Text(
                                    '${index + 1}',
                                    style: const TextStyle(color: Color(0xFF484F58)),
                                  )),
                                  DataCell(Text(
                                    item.itemName,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  )),
                                  DataCell(Text(
                                    item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2),
                                    style: const TextStyle(color: Color(0xFF58A6FF)),
                                  )),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1C2128),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF30363D)),
                                    ),
                                    child: Text(item.unit, style: const TextStyle(fontSize: 11)),
                                  )),
                                  DataCell(Text(
                                    item.note.isEmpty ? '—' : item.note,
                                    style: const TextStyle(color: Color(0xFF8B949E)),
                                  )),
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

  // Dialog ສຳລັບເພີ່ມ/ແກ້ໄຂແຜນຊື້
  void _showPlanDialog({PlanItem? item}) async {
    final isEdit = item != null;

    final itemController = TextEditingController(text: item?.itemName ?? '');
    final qtyController = TextEditingController(text: item != null ? item.quantity.toString() : '');
    final unitController = TextEditingController(text: item?.unit ?? '');
    final noteController = TextEditingController(text: item?.note ?? '');

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

// ==================== DATA CLASS ====================
class _MonthSummary {
  final int month;
  final double total;
  _MonthSummary({required this.month, required this.total});
}

// ==================== SUMMARY STAT CARD ====================
class _SummaryStatCard extends StatelessWidget {
  final String month;
  final int year;
  final int count;
  final double grandTotal;
  final String Function(double) formatMoney;

  const _SummaryStatCard({
    required this.month,
    required this.year,
    required this.count,
    required this.grandTotal,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.bar_chart_rounded, size: 15, color: Color(0xFF58A6FF)),
              const SizedBox(width: 6),
              const Text(
                'ສະຫຼຸບເດືອນນີ້',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8B949E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$month $year',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF58A6FF),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(grandTotal),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF3FB950),
                fontFamily: 'IBM Plex Mono',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2128),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Text(
                  '$count ລາຍການ',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== MONTHLY BAR CHART ====================
class _MonthlyBarChart extends StatelessWidget {
  final List<_MonthSummary> monthlyTotals;
  final double maxMonthly;
  final int selectedMonth;
  final String Function(double) formatMoney;

  static const List<String> _shortMonths = [
    'ມ.ກ', 'ກ.ພ', 'ມ.ນ', 'ມ.ສ', 'ພ.ສ', 'ມ.ຖ',
    'ກ.ກ', 'ສ.ຫ', 'ກ.ຍ', 'ຕ.ລ', 'ພ.ຈ', 'ທ.ວ',
  ];

  const _MonthlyBarChart({
    required this.monthlyTotals,
    required this.maxMonthly,
    required this.selectedMonth,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) {
    const barMaxHeight = 100.0;

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
              const Icon(Icons.stacked_bar_chart, size: 15, color: Color(0xFF8B949E)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'ລາຍຈ່າຍ 12 ເດືອນ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8B949E),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A4D2E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'ປີ ${monthlyTotals.isNotEmpty ? monthlyTotals[0].month : ""}',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF3FB950)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: barMaxHeight + 52,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: monthlyTotals.map((ms) {
                final isSelected = ms.month == selectedMonth;
                final barHeight = maxMonthly > 0
                    ? (ms.total / maxMonthly * barMaxHeight).clamp(2.0, barMaxHeight)
                    : 2.0;
                final isEmpty = ms.total == 0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 18,
                          child: (isSelected && !isEmpty)
                              ? Container(
                                  margin: const EdgeInsets.only(bottom: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3FB950),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    _compactMoney(ms.total),
                                    style: const TextStyle(
                                      fontSize: 7,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0D1117),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: isEmpty
                                ? const Color(0xFF21262D)
                                : isSelected
                                    ? const Color(0xFF3FB950)
                                    : const Color(0xFF238636).withValues(alpha: 0.7),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                            boxShadow: isSelected && !isEmpty
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF3FB950).withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, -2),
                                    )
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _shortMonths[ms.month - 1],
                          style: TextStyle(
                            fontSize: 8,
                            color: isSelected
                                ? const Color(0xFF3FB950)
                                : const Color(0xFF484F58),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFF21262D), height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ສູງສຸດ:',
                style: TextStyle(fontSize: 10, color: Color(0xFF484F58)),
              ),
              Text(
                maxMonthly > 0 ? formatMoney(maxMonthly) : '—',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8B949E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _compactMoney(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ==================== TOP ITEMS PANEL ====================
class _TopItemsPanel extends StatelessWidget {
  final List<ShoppingItem> topItems;
  final double grandTotal;
  final String Function(double) formatMoney;

  const _TopItemsPanel({
    required this.topItems,
    required this.grandTotal,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.emoji_events_outlined,
                  size: 15, color: Color(0xFFD29922)),
              const SizedBox(width: 6),
              const Text(
                'Top 5 ລາຍການ (ງົບຫຼາຍສຸດ)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8B949E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (topItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'ຍັງບໍ່ມີຂໍ້ມູນ',
                  style: TextStyle(fontSize: 12, color: Color(0xFF484F58)),
                ),
              ),
            )
          else
            ...topItems.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final pct = grandTotal > 0 ? item.totalPrice / grandTotal : 0.0;

              final rankColors = [
                const Color(0xFFD29922),
                const Color(0xFF8B949E),
                const Color(0xFFBF8B56),
                const Color(0xFF484F58),
                const Color(0xFF484F58),
              ];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: rankColors[idx].withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: rankColors[idx].withValues(alpha: 0.5)),
                          ),
                          child: Center(
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: rankColors[idx],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.itemName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFE6EDF3),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(pct * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: rankColors[idx],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const SizedBox(width: 26),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF21262D),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: pct.clamp(0.0, 1.0),
                                child: Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: rankColors[idx],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatMoney(item.totalPrice),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}