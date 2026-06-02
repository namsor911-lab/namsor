import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import 'package:accounting/models/models.dart';
import 'package:accounting/utils/constants.dart';

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
    final filteredTx = widget.transactions.where((t) {
      return t.date.year == _selectedYear &&
          t.date.month == _selectedMonth &&
          (_searchQuery.isEmpty ||
              t.desc.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              t.note.toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();

    final monthAllTx = widget.transactions.where((t) {
      return t.date.year == _selectedYear && t.date.month == _selectedMonth;
    }).toList();

    final openingBalance = getOpeningBalance(widget.transactions, _selectedYear, _selectedMonth);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _buildDocumentHeader(),
        const SizedBox(height: 16),
        Card(child: Column(children: [
          _buildCardHeader(),
          _buildFilterBar(),
          SizedBox(width: double.infinity, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: _buildTransactionTable(filteredTx))),
        ])),
        const SizedBox(height: 16),
        _buildStatsSummary(monthAllTx, openingBalance),
        const SizedBox(height: 16),
        _buildSignatureSection(),
      ]),
    );
  }

  Widget _buildDocumentHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1C2128), border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        const Text('ສາທາລະນະລັດ ປະຊາທິປະໄຕ ປະຊາຊົນລາວ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const Text('ສັນຕິພາບ ເອກະລາດ ປະຊາທິປະໄຕ ເອກະພາບ ວັດທະນະຖາວອນ', style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),
        const Text('📒 ບັນຊີລາຍຮັບ-ລາຍຈ່າຍເງິນແຮສະໜາມ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const Text('ບໍລິສັດ: ເຂື່ອນໄຟຟ້ານ້ຳຊໍ້ ເມືອງວຽງທອງ ແຂວງບໍລິຄຳໄຊ', style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('📅 ເດືອນ: ${months[_selectedMonth - 1]} $_selectedYear', style: const TextStyle(fontSize: 12, color: Color(0xFF484F58))),
          const SizedBox(width: 20),
          const Text('📍 ສະຖານທີ່: ພາກສະໜາມ', style: TextStyle(fontSize: 12, color: Color(0xFF484F58))),
        ]),
      ]),
    );
  }

  Widget _buildCardHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        const Expanded(child: Text('📄 ລາຍການເງິນ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        IconButton(icon: const Icon(Icons.download, size: 18), onPressed: _exportCSV, tooltip: 'Export CSV'),
        const SizedBox(width: 4),
        ElevatedButton.icon(onPressed: () => _showTransactionDialog(), icon: const Icon(Icons.add, size: 16), label: const Text('ເພີ່ມລາຍການ'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636))),
      ]),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        DropdownButton<int>(
          value: _selectedMonth,
          dropdownColor: const Color(0xFF1C2128),
          underline: const SizedBox(),
          items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i]))),
          onChanged: (value) => setState(() => _selectedMonth = value!),
        ),
        const SizedBox(width: 12),
        DropdownButton<int>(
          value: _selectedYear,
          dropdownColor: const Color(0xFF1C2128),
          underline: const SizedBox(),
          items: [DateTime.now().year - 3, DateTime.now().year - 2, DateTime.now().year - 1, DateTime.now().year, DateTime.now().year + 1].map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
          onChanged: (value) => setState(() => _selectedYear = value!),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: const InputDecoration(hintText: 'ຄົ້ນຫາ...', prefixIcon: Icon(Icons.search, size: 14), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          ),
        ),
      ]),
    );
  }

  Widget _buildTransactionTable(List<Transaction> txList) {
    if (txList.isEmpty) {
      return const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('ບໍ່ມີລາຍການໃນເດືອນນີ້', style: TextStyle(color: Color(0xFF8B949E)))));
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
          DataCell(Text('${i + 1}', style: const TextStyle(color: Color(0xFF8B949E)))),
          DataCell(Text('${t.date.day}/${t.date.month}/${t.date.year}', style: const TextStyle(fontFamily: 'IBM Plex Mono', fontSize: 12))),
          DataCell(Text(t.desc)),
          DataCell(Text(t.income > 0 ? formatMoney(t.income) : '-', style: const TextStyle(color: Color(0xFF3FB950)))),
          DataCell(Text(t.expense > 0 ? formatMoney(t.expense) : '-', style: const TextStyle(color: Color(0xFFF85149)))),
          DataCell(Text(formatMoneyWithSign(t.balance), style: TextStyle(color: t.balance >= 0 ? const Color(0xFF3FB950) : const Color(0xFFF85149)))),
          DataCell(Text(t.note.isNotEmpty ? t.note : '-', style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)))),
          DataCell(Row(children: [
            IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showTransactionDialog(transaction: t)),
            IconButton(icon: const Icon(Icons.delete, size: 16), onPressed: () => _deleteTransaction(t.id)),
          ])),
        ]);
      }),
    );
  }

  Widget _buildStatsSummary(List<Transaction> monthTx, double openingBalance) {
    final totalInc = monthTx.fold(0.0, (s, t) => s + t.income);
    final totalExp = monthTx.fold(0.0, (s, t) => s + t.expense);
    final closingBalance = openingBalance + totalInc - totalExp;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C2128), border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _SummaryItem(label: 'ຍອດຍົກມາ', value: formatMoneyWithSign(openingBalance), color: const Color(0xFF8B949E)),
        _SummaryItem(label: 'ລາຍຮັບ', value: formatMoney(totalInc), color: const Color(0xFF3FB950)),
        _SummaryItem(label: 'ລາຍຈ່າຍ', value: formatMoney(totalExp), color: const Color(0xFFF85149)),
        _SummaryItem(label: 'ຍອດຄົງເຫຼືອ', value: formatMoneyWithSign(closingBalance), color: closingBalance >= 0 ? const Color(0xFF3FB950) : const Color(0xFFF85149)),
      ]),
    );
  }

  Widget _buildSignatureSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C2128), border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('✍️ ລາຍເຊັນອະນຸຍາດ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: signatureRoles.map((role) {
          return SizedBox(width: 200, child: _SignatureBox(role: role, signature: widget.signatures[role], onUpdate: (data) => widget.onUpdateSignature(role, data), onDelete: () => widget.onDeleteSignature(role)));
        }).toList()),
      ]),
    );
  }

  void _showTransactionDialog({Transaction? transaction}) async {
    final isEdit = transaction != null;
    DateTime selectedDate = transaction?.date ?? DateTime.now();
    bool isIncome = transaction != null && transaction.income > 0;
    final descController = TextEditingController(text: transaction?.desc ?? '');
    final amountController = TextEditingController(text: isEdit ? (isIncome ? transaction.income : transaction.expense).toStringAsFixed(0) : '');
    final noteController = TextEditingController(text: transaction?.note ?? '');

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'ແກ້ໄຂລາຍການ' : 'ເພີ່ມລາຍການ'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                title: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (date != null) setDialogState(() => selectedDate = date);
                },
              ),
              TextField(controller: descController, decoration: const InputDecoration(labelText: 'ເນື້ອໃນລາຍການ')),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: true, label: Text('💰 ລາຍຮັບ')), ButtonSegment(value: false, label: Text('💸 ລາຍຈ່າຍ'))],
                selected: {isIncome},
                onSelectionChanged: (set) => setDialogState(() => isIncome = set.first),
              ),
              const SizedBox(height: 12),
              TextField(controller: amountController, decoration: const InputDecoration(labelText: 'ຈຳນວນເງິນ (₭)'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: 'ໝາຍເຫດ (ຖ້າມີ)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ຍົກເລີກ')),
            ElevatedButton(
              onPressed: () {
                final desc = descController.text.trim();
                final amount = double.tryParse(amountController.text) ?? 0;
                if (desc.isEmpty || amount <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('ກະລຸນາປ້ອນຂໍ້ມູນໃຫ້ຄົບ')));
                  return;
                }
                final t = Transaction(id: isEdit ? transaction.id : DateTime.now().millisecondsSinceEpoch.toString(), date: selectedDate, desc: desc, income: isIncome ? amount : 0, expense: isIncome ? 0 : amount, note: noteController.text);
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ຍົກເລີກ')),
          TextButton(onPressed: () { widget.onDeleteTransaction(id); if (context.mounted) Navigator.pop(context); }, child: const Text('ລຶບ', style: TextStyle(color: Color(0xFFF85149)))),
        ],
      ),
    );
  }

  void _exportCSV() {
    final txList = widget.transactions.where((t) => t.date.year == _selectedYear && t.date.month == _selectedMonth).toList();
    final opening = getOpeningBalance(widget.transactions, _selectedYear, _selectedMonth);
    double rb = opening;
    final lines = <String>[' FEFFລ/ດ,ວັນທີ,ເນື້ອໃນ,ລາຍຮັບ(₭),ລາຍຈ່າຍ(₭),ຍອດເຫຼືອ(₭),ໝາຍເຫດ'];
    for (int i = 0; i < txList.length; i++) {
      final t = txList[i];
      rb += t.income - t.expense;
      lines.add('${i + 1},${t.date.day}/${t.date.month}/${t.date.year},"${t.desc}",${t.income},${t.expense},$rb,"${t.note}"');
    }
    final totalInc = txList.fold(0.0, (s, t) => s + t.income);
    final totalExp = txList.fold(0.0, (s, t) => s + t.expense);
    lines.add(',,ລວມ,$totalInc,$totalExp,${opening + totalInc - totalExp},');

    final blob = html.Blob([lines.join('\n')], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrl(blob);
    html.AnchorElement(href: url)
      ..download = 'acc_${months[_selectedMonth - 1]}_$_selectedYear.csv'
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

class _SignatureBox extends StatefulWidget {
  final String role;
  final SignatureData? signature;
  final Function(SignatureData) onUpdate;
  final VoidCallback onDelete;

  const _SignatureBox({required this.role, this.signature, required this.onUpdate, required this.onDelete});

  @override
  State<_SignatureBox> createState() => _SignatureBoxState();
}

class _SignatureBoxState extends State<_SignatureBox> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.signature?.name ?? '');
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
      decoration: BoxDecoration(color: const Color(0xFF161B22), border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(widget.role, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B949E))),
        const SizedBox(height: 8),
        if (hasSignature)
          Container(height: 50, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF3FB950)), borderRadius: BorderRadius.circular(6)), child: const Center(child: Text('✅ ອະນຸຍາດ', style: TextStyle(fontSize: 11, color: Color(0xFF3FB950)))))
        else
          Container(height: 50, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(6)), child: const Center(child: Text('ຍັງບໍ່ເຊັນ', style: TextStyle(fontSize: 11, color: Color(0xFF8B949E))))),
        const SizedBox(height: 8),
        if (hasSignature)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: () => _showSignatureDialog(context), child: const Text('ແກ້ໄຂ', style: TextStyle(fontSize: 11))),
            TextButton(onPressed: widget.onDelete, child: const Text('ລຶບ', style: TextStyle(fontSize: 11, color: Color(0xFFF85149)))),
          ])
        else
          ElevatedButton(onPressed: () => _showSignatureDialog(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C2128), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)), child: const Text('✍️ ເຊັນ', style: TextStyle(fontSize: 11))),
        const SizedBox(height: 4),
        TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'ຊື່ ແລະ ນາມສະກຸນ...', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11), onChanged: (value) => widget.onUpdate(SignatureData(name: value, approved: widget.signature?.approved ?? false, dataUrl: widget.signature?.dataUrl, ts: widget.signature?.ts))),
        if (hasSignature) ...[
          const SizedBox(height: 4),
          Text('✅ ອະນຸຍາດ ${widget.signature!.ts}', style: const TextStyle(fontSize: 10, color: Color(0xFF3FB950))),
        ],
      ]),
    );
  }

  void _showSignatureDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ເຊັນອະນຸຍາດ - ${widget.role}'),
        content: const Text('ຢືນຢັນການອະນຸຍາດ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ຍົກເລີກ')),
          ElevatedButton(onPressed: () { widget.onUpdate(SignatureData(approved: true, ts: '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', name: _nameController.text, dataUrl: widget.signature?.dataUrl)); if (dialogContext.mounted) Navigator.pop(dialogContext); }, child: const Text('ຢືນຢັນ')),
        ],
      ),
    );
  }
}
