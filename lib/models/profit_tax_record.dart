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

  factory ProfitTaxRecord.fromJson(Map<String, dynamic> json) => ProfitTaxRecord(
        id: json['id'] as String,
        periodTitle: json['periodTitle'] as String,
        totalRevenue: (json['totalRevenue'] as num).toDouble(),
        totalExpense: (json['totalExpense'] as num).toDouble(),
        taxRate: (json['taxRate'] as num? ?? 20.0).toDouble(),
      );
}
