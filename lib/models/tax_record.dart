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

  factory TaxRecord.fromJson(Map<String, dynamic> json) => TaxRecord(
        id: json['id'] as String,
        employeeName: json['employeeName'] as String,
        position: json['position'] as String,
        grossSalary: (json['grossSalary'] as num).toDouble(),
        taxRate: (json['taxRate'] as num).toDouble(),
      );
}
