class BudgetPlanItem {
  final String id;
  String itemName;
  String category;
  String status;
  String note;
  String monthKey;
  double plannedAmount;
  double actualAmount;
  List<String> receipts;
  String? sigResponsible;
  String? sigDirector;
  String? sigChief;
  String? sigApprover;

  BudgetPlanItem({
    required this.id,
    required this.itemName,
    required this.category,
    required this.plannedAmount,
    required this.monthKey,
    this.actualAmount = 0,
    this.status = 'ວາງແຜນ',
    this.note = '',
    this.receipts = const [],
    this.sigResponsible,
    this.sigDirector,
    this.sigChief,
    this.sigApprover,
  });

  double get remaining => plannedAmount - actualAmount;

  double get progressPct {
    if (plannedAmount <= 0) return 0.0;
    return (actualAmount / plannedAmount * 100).clamp(0.0, 100.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemName': itemName,
        'category': category,
        'plannedAmount': plannedAmount,
        'actualAmount': actualAmount,
        'status': status,
        'note': note,
        'monthKey': monthKey,
        'receipts': receipts,
        'sigResponsible': sigResponsible,
        'sigDirector': sigDirector,
        'sigChief': sigChief,
        'sigApprover': sigApprover,
      };

  factory BudgetPlanItem.fromJson(Map<String, dynamic> json) => BudgetPlanItem(
        id: json['id'] as String,
        itemName: json['itemName'] as String? ?? '',
        category: json['category'] as String? ?? 'ອື່ນໆ',
        plannedAmount: (json['plannedAmount'] as num? ?? 0).toDouble(),
        actualAmount: (json['actualAmount'] as num? ?? 0).toDouble(),
        status: json['status'] as String? ?? 'ວາງແຜນ',
        note: json['note'] as String? ?? '',
        monthKey: json['monthKey'] as String? ?? '',
        receipts: List<String>.from((json['receipts'] as List?)?.whereType<String>() ?? []),
        sigResponsible: json['sigResponsible'] as String?,
        sigDirector: json['sigDirector'] as String?,
        sigChief: json['sigChief'] as String?,
        sigApprover: json['sigApprover'] as String?,
      );
}
