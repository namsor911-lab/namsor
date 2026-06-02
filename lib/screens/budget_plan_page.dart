import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:accounting/models/models.dart';
import 'package:accounting/services/services.dart';
import 'package:accounting/utils/constants.dart';

class BudgetPlanPage extends StatefulWidget {
  const BudgetPlanPage({super.key});

  @override
  State<BudgetPlanPage> createState() => _BudgetPlanPageState();
}

class _BudgetPlanPageState extends State<BudgetPlanPage> {
  int _selMonth = DateTime.now().month;
  int _selYear = DateTime.now().year;

  String get _mk => '${_selYear}_${_selMonth.toString().padLeft(2, '0')}';

  String _fmt(double v) => '${formatMoney(v)} ₭';

  Color _statusColor(String status) {
    switch (status) {
      case 'ສຳເລັດ':
        return const Color(0xFF3FB950);
      case 'ກຳລັງດຳເນີນ':
        return const Color(0xFFD29922);
      case 'ຍົກເລີກ':
        return const Color(0xFFF85149);
      default:
        return const Color(0xFF8B949E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BudgetPlanItem>>(
      stream: BudgetPlanService.streamByMonth(_mk),
      builder: (context, snap) {
        final items = snap.data ?? [];
        final totalPlan = items.fold(0.0, (s, i) => s + i.plannedAmount);
        final totalUsed = items.fold(0.0, (s, i) => s + i.actualAmount);
        final totalLeft = totalPlan - totalUsed;

        return Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          body: SafeArea(
            child: SingleChildScrollView(
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
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF1A4D2E), Color(0xFF238636)]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(child: Text('📋', style: TextStyle(fontSize: 18))),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('ແຜນການຊື້ເຄື່ອງປະຈຳເດືອນ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFE6EDF3))),
                            Text('ວາງແຜນງົບ ແລະ ຕິດຕາມ', style: TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
                          ]),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showBudgetDialog(),
                          icon: const Icon(Icons.add, size: 15),
                          label: const Text('ເພີ່ມລາຍການ', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        const Text('📅 ເດືອນ: ', style: TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: _selMonth,
                          dropdownColor: const Color(0xFF1C2128),
                          underline: const SizedBox(),
                          items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i], style: const TextStyle(fontSize: 13)))),
                          onChanged: (v) => setState(() => _selMonth = v!),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: _selYear,
                          dropdownColor: const Color(0xFF1C2128),
                          underline: const SizedBox(),
                          items: List.generate(5, (i) {
                            final y = DateTime.now().year - 1 + i;
                            return DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 13)));
                          }),
                          onChanged: (v) => setState(() => _selYear = v!),
                        ),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    _summaryCard('💰 ງົບວາງແຜນ', _fmt(totalPlan), const Color(0xFF3FB950)),
                    const SizedBox(width: 10),
                    _summaryCard('🛒 ໃຊ້ໄປ', _fmt(totalUsed), const Color(0xFFF85149)),
                    const SizedBox(width: 10),
                    _summaryCard('📊 ຄົງເຫຼືອ', _fmt(totalLeft), totalLeft >= 0 ? const Color(0xFF3FB950) : const Color(0xFFF85149)),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(color: const Color(0xFF161B22), border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(10)),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF21262D))), borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10))),
                        child: Row(children: const [
                          SizedBox(width: 32, child: Text('#', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700))),
                          Expanded(flex: 3, child: Text('ລາຍການ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                          Expanded(flex: 2, child: Text('ໝວດ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                          Expanded(flex: 2, child: Text('ງົບ (₭)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text('ໃຊ້ (₭)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text('ສະຖານະ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                          SizedBox(width: 70),
                        ]),
                      ),
                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('ຍັງບໍ່ມີລາຍການ', style: TextStyle(color: Color(0xFF8B949E))),
                        )
                      else
                        ...items.asMap().entries.map((e) => _buildRow(e.key, e.value)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  _buildSigSection(items),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _summaryCard(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF161B22), border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      );

  Widget _buildRow(int idx, BudgetPlanItem item) {
    final pct = item.progressPct;
    final barColor = pct >= 100 ? const Color(0xFFF85149) : pct >= 80 ? const Color(0xFFD29922) : const Color(0xFF3FB950);
    return InkWell(
      onTap: () => _showDetail(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: idx.isEven ? Colors.transparent : const Color(0xFF0D1117).withValues(alpha: 0.4),
          border: const Border(bottom: BorderSide(color: Color(0xFF21262D))),
        ),
        child: Row(children: [
          SizedBox(width: 32, child: Container(width: 22, height: 22, decoration: BoxDecoration(color: const Color(0xFF21262D), borderRadius: BorderRadius.circular(4)), child: Center(child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)))))),
          Expanded(flex: 3, child: Text(item.itemName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFE6EDF3)))),
          Expanded(flex: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF1F6FEB).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text(item.category, style: const TextStyle(fontSize: 11, color: Color(0xFF58A6FF)), textAlign: TextAlign.center))),
          Expanded(flex: 2, child: Text(_fmt(item.plannedAmount), style: const TextStyle(fontSize: 12, color: Color(0xFF3FB950)), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(_fmt(item.actualAmount), style: TextStyle(fontSize: 12, color: item.remaining < 0 ? const Color(0xFFF85149) : const Color(0xFFE6EDF3)), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Column(children: [
            Text(item.status, style: TextStyle(fontSize: 11, color: _statusColor(item.status), fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            const SizedBox(height: 3),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct / 100, backgroundColor: const Color(0xFF21262D), color: barColor, minHeight: 4)),
            Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, color: Color(0xFF8B949E)), textAlign: TextAlign.center),
          ])),
          SizedBox(width: 70, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _iconBtn(Icons.edit_outlined, const Color(0xFF58A6FF), () => _showBudgetDialog(item: item)),
            const SizedBox(width: 4),
            _iconBtn(Icons.delete_outline, const Color(0xFFF85149), () => _deleteItem(item)),
          ])),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback fn) => InkWell(
        onTap: fn,
        borderRadius: BorderRadius.circular(4),
        child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Icon(icon, size: 14, color: color)),
      );

  Widget _buildSigSection(List<BudgetPlanItem> items) {
    final first = items.isNotEmpty ? items.first : null;
    String? getSig(String role) {
      if (first == null) return null;
      switch (role) {
        case 'ຜູ້ຮັບຜິດຊອບ':
          return first.sigResponsible;
        case 'ຜູ້ອຳນວຍການ':
          return first.sigDirector;
        case 'ຫົວໜ້າເຂື່ອນ':
          return first.sigChief;
        case 'ຜູ້ອະນຸມັດ':
          return first.sigApprover;
        default:
          return null;
      }
    }

    String? dbField(String role) {
      switch (role) {
        case 'ຜູ້ຮັບຜິດຊອບ':
          return 'sigResponsible';
        case 'ຜູ້ອຳນວຍການ':
          return 'sigDirector';
        case 'ຫົວໜ້າເຂື່ອນ':
          return 'sigChief';
        case 'ຜູ້ອະນຸມັດ':
          return 'sigApprover';
        default:
          return null;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF161B22), border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('✍️ ລາຍເຊັນອະນຸມັດແຜນ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3))),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: budgetSignatureRoles.map((role) {
            final url = getSig(role);
            final hasSig = url != null && url.isNotEmpty;
            return Container(
              decoration: BoxDecoration(color: const Color(0xFF0D1117), border: Border.all(color: hasSig ? const Color(0xFF3FB950) : const Color(0xFF30363D)), borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Expanded(
                  child: hasSig
                      ? Image.network(url, fit: BoxFit.contain, errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Color(0xFF8B949E)))
                      : const Center(child: Text('ຍັງບໍ່ເຊັນ', style: TextStyle(fontSize: 11, color: Color(0xFF8B949E)))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF30363D)))),
                  child: Row(children: [
                    Expanded(child: Text(role, style: const TextStyle(fontSize: 9, color: Color(0xFF8B949E)), overflow: TextOverflow.ellipsis)),
                    GestureDetector(
                      onTap: () async {
                        if (hasSig) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF161B22),
                              content: Text('ລຶບລາຍເຊັນ "$role"?', style: const TextStyle(color: Color(0xFFE6EDF3))),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ຍົກເລີກ')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ລຶບ', style: TextStyle(color: Color(0xFFF85149)))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await BudgetPlanService.updateSig(_mk, dbField(role)!, null);
                          }
                        } else {
                          await _pickSig(role, dbField(role)!);
                        }
                      },
                      child: Icon(hasSig ? Icons.close : Icons.draw_outlined, size: 14, color: hasSig ? const Color(0xFFF85149) : const Color(0xFF3FB950)),
                    ),
                  ]),
                ),
              ]),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Future<void> _pickSig(String role, String field) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final url = await ReceiptStorageService.uploadReceipt('sigs', bytes, 'budget_${role}_$_mk.jpg');
    if (url != null) {
      await BudgetPlanService.updateSig(_mk, field, url);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ອັບໂຫລດລົ້ມເຫລວ')));
    }
  }

  void _showDetail(BudgetPlanItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFF30363D))),
        title: Text(item.itemName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3))),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                _detailTile('ງົບ', _fmt(item.plannedAmount), const Color(0xFF3FB950)),
                const SizedBox(width: 8),
                _detailTile('ໃຊ້', _fmt(item.actualAmount), const Color(0xFFF85149)),
                const SizedBox(width: 8),
                _detailTile('ເຫຼືອ', _fmt(item.remaining), item.remaining >= 0 ? const Color(0xFF3FB950) : const Color(0xFFF85149)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: item.progressPct / 100, backgroundColor: const Color(0xFF21262D), color: const Color(0xFF3FB950), minHeight: 8)),
              if (item.note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(6)), child: Text(item.note, style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E)))),
              ],
              if (item.receipts.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('🧾 ໃບບິນ', style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: item.receipts.map((url) => GestureDetector(
                      onTap: () => showDialog(context: ctx, builder: (c) => Dialog(backgroundColor: Colors.transparent, child: GestureDetector(onTap: () => Navigator.pop(c), child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))))),
                      child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image))),
                    )).toList()),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ປິດ')),
          TextButton(onPressed: () { Navigator.pop(ctx); _showBudgetDialog(item: item); }, child: const Text('✏️ ແກ້ໄຂ', style: TextStyle(color: Color(0xFF58A6FF)))),
          TextButton(onPressed: () { Navigator.pop(ctx); _deleteItem(item); }, child: const Text('🗑 ລຶບ', style: TextStyle(color: Color(0xFFF85149)))),
        ],
      ),
    );
  }

  Widget _detailTile(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(6)),
          child: Column(children: [Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF8B949E))), const SizedBox(height: 4), Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color))]),
        ),
      );

  void _showBudgetDialog({BudgetPlanItem? item}) {
    final isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?.itemName ?? '');
    final planCtrl = TextEditingController(text: item != null ? item.plannedAmount.toStringAsFixed(0) : '');
    final usedCtrl = TextEditingController(text: item != null ? item.actualAmount.toStringAsFixed(0) : '');
    final noteCtrl = TextEditingController(text: item?.note ?? '');
    String selCat = item?.category ?? budgetCategories.first;
    String selStatus = item?.status ?? 'ວາງແຜນ';
    List<String> rcts = List<String>.from(item?.receipts ?? []);

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (bCtx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFF30363D))),
          title: Text(isEdit ? 'ແກ້ໄຂລາຍການ' : 'ເພີ່ມລາຍການ', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3))),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: nameCtrl, style: const TextStyle(color: Color(0xFFE6EDF3)), decoration: const InputDecoration(labelText: 'ຊື່ລາຍການ *')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(initialValue: selCat, dropdownColor: const Color(0xFF1C2128), decoration: const InputDecoration(labelText: 'ໝວດໝູ່'), items: budgetCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setS(() => selCat = v!))),
                  const SizedBox(width: 12),
                  Expanded(child: DropdownButtonFormField<String>(initialValue: selStatus, dropdownColor: const Color(0xFF1C2128), decoration: const InputDecoration(labelText: 'ສະຖານະ'), items: const [
                    DropdownMenuItem(value: 'ວາງແຜນ', child: Text('📝 ວາງແຜນ')),
                    DropdownMenuItem(value: 'ກຳລັງດຳເນີນ', child: Text('🔄 ກຳລັງດຳເນີນ')),
                    DropdownMenuItem(value: 'ສຳເລັດ', child: Text('✅ ສຳເລັດ')),
                    DropdownMenuItem(value: 'ຍົກເລີກ', child: Text('❌ ຍົກເລີກ')),
                  ], onChanged: (v) => setS(() => selStatus = v!))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: planCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Color(0xFFE6EDF3)), decoration: const InputDecoration(labelText: 'ງົບວາງແຜນ (₭) *'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: usedCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Color(0xFFE6EDF3)), decoration: const InputDecoration(labelText: 'ໃຊ້ຈິງ (₭)'))),
                ]),
                const SizedBox(height: 12),
                TextField(controller: noteCtrl, style: const TextStyle(color: Color(0xFFE6EDF3)), decoration: const InputDecoration(labelText: 'ໝາຍເຫດ')),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF0D1117), border: Border.all(color: const Color(0xFF30363D)), borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('📎 ຮູບໃບບິນ', style: TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                          if (picked == null) return;
                          final bytes = await picked.readAsBytes();
                          if (!bCtx.mounted) return;
                          ScaffoldMessenger.of(bCtx).showSnackBar(const SnackBar(content: Text('⏳ ກຳລັງອັບໂຫລດ...')));
                          final url = await ReceiptStorageService.uploadReceipt('receipts', bytes, picked.name);
                          if (url != null) {
                            setS(() => rcts.add(url));
                          }
                        },
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 14),
                        label: const Text('ເພີ່ມ', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF3FB950)),
                      ),
                    ]),
                    if (rcts.isNotEmpty)
                      Wrap(spacing: 8, runSpacing: 8, children: rcts.asMap().entries.map((e) => Stack(children: [
                            ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(e.value, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image))),
                            Positioned(top: 0, right: 0, child: GestureDetector(onTap: () => setS(() => rcts.removeAt(e.key)), child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: Color(0xFFF85149), shape: BoxShape.circle), child: const Icon(Icons.close, size: 10, color: Colors.white)))),
                          ])).toList())
                    else
                      const Text('ຍັງບໍ່ມີ', style: TextStyle(fontSize: 11, color: Color(0xFF484F58))),
                  ]),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('ຍົກເລີກ')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final plan = double.tryParse(planCtrl.text) ?? 0;
                if (name.isEmpty || plan <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ກະລຸນາໃສ່ຊື່ ແລະ ງົບ')));
                  return;
                }
                final budgetItem = BudgetPlanItem(
                  id: item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  itemName: name,
                  category: selCat,
                  plannedAmount: plan,
                  actualAmount: double.tryParse(usedCtrl.text) ?? 0,
                  status: selStatus,
                  note: noteCtrl.text.trim(),
                  monthKey: _mk,
                  receipts: rcts,
                  sigResponsible: item?.sigResponsible,
                  sigDirector: item?.sigDirector,
                  sigChief: item?.sigChief,
                  sigApprover: item?.sigApprover,
                );
                await BudgetPlanService.save(budgetItem);
                if (dCtx.mounted) Navigator.pop(dCtx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? '✅ ແກ້ໄຂສຳເລັດ' : '✅ ເພີ່ມລາຍການສຳເລັດ')));
                }
              },
              child: Text(isEdit ? 'ບັນທຶກ' : 'ເພີ່ມ', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteItem(BudgetPlanItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFF30363D))),
        content: Text('ລຶບ "${item.itemName}" ແທ້ ຫຼື ບໍ່?', style: const TextStyle(color: Color(0xFF8B949E))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ຍົກເລີກ')),
          TextButton(
            onPressed: () async {
              await BudgetPlanService.delete(item.id);
              for (final url in item.receipts) {
                await ReceiptStorageService.deleteUrl(url);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('ລຶບ', style: TextStyle(color: Color(0xFFF85149))),
          ),
        ],
      ),
    );
  }
}
