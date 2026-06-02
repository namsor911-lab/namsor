import 'package:flutter/material.dart';

import 'package:accounting/models/models.dart';
import 'package:accounting/services/services.dart';
import 'package:accounting/utils/constants.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('ບັນຊີລາຍການຊື້ເຄື່ອງ'),
        centerTitle: false,
        backgroundColor: const Color(0xFF161B22),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'ລາຍການ'), Tab(text: 'ແຜນຊື້')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildShoppingItems(),
          _buildPlanItems(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _showShoppingItemDialog();
          } else {
            _showPlanItemDialog();
          }
        },
        backgroundColor: const Color(0xFF238636),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildShoppingItems() {
    return StreamBuilder<List<ShoppingItem>>(
      stream: ShoppingItemService.stream(),
      builder: (context, snap) {
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('ຍັງບໍ່ມີລາຍການ', style: TextStyle(color: Color(0xFF8B949E))));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              color: const Color(0xFF161B22),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(item.itemName, style: const TextStyle(color: Colors.white)),
                subtitle: Text('${formatMoney(item.totalPrice)} • ${item.quantity} ${item.unit}', style: const TextStyle(color: Color(0xFF8B949E))),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit, color: Color(0xFF58A6FF)), onPressed: () => _showShoppingItemDialog(item: item)),
                  IconButton(icon: const Icon(Icons.delete, color: Color(0xFFF85149)), onPressed: () => ShoppingItemService.delete(item.id)),
                ]),
                onTap: () => _showShoppingItemDialog(item: item),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlanItems() {
    return StreamBuilder<List<PlanItem>>(
      stream: PlanItemService.stream(),
      builder: (context, snap) {
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('ຍັງບໍ່ມີແຜນການຊື້', style: TextStyle(color: Color(0xFF8B949E))));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              color: const Color(0xFF161B22),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(item.itemName, style: const TextStyle(color: Colors.white)),
                subtitle: Text('${item.quantity} ${item.unit}', style: const TextStyle(color: Color(0xFF8B949E))),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit, color: Color(0xFF58A6FF)), onPressed: () => _showPlanItemDialog(item: item)),
                  IconButton(icon: const Icon(Icons.delete, color: Color(0xFFF85149)), onPressed: () => PlanItemService.delete(item.id)),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  void _showShoppingItemDialog({ShoppingItem? item}) {
    final isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?.itemName ?? '');
    final qtyCtrl = TextEditingController(text: item?.quantity.toString() ?? '1');
    final priceCtrl = TextEditingController(text: item?.unitPrice.toString() ?? '0');
    final unitCtrl = TextEditingController(text: item?.unit ?? '');
    final noteCtrl = TextEditingController(text: item?.note ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(isEdit ? 'ແກ້ໄຂລາຍການ' : 'ເພີ່ມລາຍການ', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ລາຍການ', labelStyle: TextStyle(color: Color(0xFF8B949E))), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'ຈຳນວນ', labelStyle: TextStyle(color: Color(0xFF8B949E))), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'ລາຄາ໕ຕ່າງ', labelStyle: TextStyle(color: Color(0xFF8B949E))), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'ຫົວໜ່ວຍ', labelStyle: TextStyle(color: Color(0xFF8B949E))), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'ໝາຍເຫດ', labelStyle: TextStyle(color: Color(0xFF8B949E))), style: const TextStyle(color: Colors.white)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ຍົກເລີກ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final qty = double.tryParse(qtyCtrl.text) ?? 0;
              final price = double.tryParse(priceCtrl.text) ?? 0;
              if (name.isEmpty || qty <= 0 || price <= 0) {
                return;
              }
              final newItem = ShoppingItem(
                id: item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                itemName: name,
                date: DateTime.now(),
                quantity: qty,
                unitPrice: price,
                unit: unitCtrl.text.trim().isEmpty ? 'ອັນ' : unitCtrl.text.trim(),
                note: noteCtrl.text.trim(),
              );
              if (isEdit) {
                ShoppingItemService.update(newItem);
              } else {
                ShoppingItemService.add(newItem);
              }
              Navigator.pop(context);
            },
            child: Text(isEdit ? 'ບັນທຶກ' : 'ເພີ່ມ'),
          ),
        ],
      ),
    );
  }

  void _showPlanItemDialog({PlanItem? item}) {
    final isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?.itemName ?? '');
    final qtyCtrl = TextEditingController(text: item?.quantity.toString() ?? '1');
    final unitCtrl = TextEditingController(text: item?.unit ?? 'ອັນ');
    final noteCtrl = TextEditingController(text: item?.note ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(isEdit ? 'ແກ້ໄຂແຜນຊື້' : 'ເພີ່ມແຜນຊື້', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ລາຍການ', labelStyle: TextStyle(color: Color(0xFF8B949E))), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'ຈຳນວນ', labelStyle: TextStyle(color: Color(0xFF8B949E))), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'ຫົວໜ່ວຍ', labelStyle: TextStyle(color: Color(0xFF8B949E))), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'ໝາຍເຫດ', labelStyle: TextStyle(color: Color(0xFF8B949E))), style: const TextStyle(color: Colors.white)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ຍົກເລີກ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final qty = double.tryParse(qtyCtrl.text) ?? 0;
              if (name.isEmpty || qty <= 0) {
                return;
              }
              final newItem = PlanItem(
                id: item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                itemName: name,
                quantity: qty,
                unit: unitCtrl.text.trim().isEmpty ? 'ອັນ' : unitCtrl.text.trim(),
                note: noteCtrl.text.trim(),
              );
              if (isEdit) {
                PlanItemService.update(newItem);
              } else {
                PlanItemService.add(newItem);
              }
              Navigator.pop(context);
            },
            child: Text(isEdit ? 'ບັນທຶກ' : 'ເພີ່ມ'),
          ),
        ],
      ),
    );
  }
}
