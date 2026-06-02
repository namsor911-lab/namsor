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
