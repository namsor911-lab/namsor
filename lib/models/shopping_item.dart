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
