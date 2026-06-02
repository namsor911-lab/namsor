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

  factory VatRecord.fromJson(Map<String, dynamic> json) => VatRecord(
        id: json['id'] as String,
        invoiceNo: json['invoiceNo'] as String,
        detail: json['detail'] as String,
        amountBeforeVat: (json['amountBeforeVat'] as num).toDouble(),
        vatRate: (json['vatRate'] as num? ?? 10.0).toDouble(),
      );
}
