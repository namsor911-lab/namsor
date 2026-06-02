class Transaction {
  final String id;
  final DateTime date;
  final String desc;
  final double income;
  final double expense;
  final String note;
  double balance;

  Transaction({
    required this.id,
    required this.date,
    required this.desc,
    required this.income,
    required this.expense,
    this.note = '',
    this.balance = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'desc': desc,
        'income': income,
        'expense': expense,
        'note': note,
        'balance': balance,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        desc: json['desc'] as String,
        income: (json['income'] as num?)?.toDouble() ?? 0.0,
        expense: (json['expense'] as num?)?.toDouble() ?? 0.0,
        note: json['note'] as String? ?? '',
        balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      );

  Transaction copyWith({
    String? id,
    DateTime? date,
    String? desc,
    double? income,
    double? expense,
    String? note,
    double? balance,
  }) {
    return Transaction(
      id: id ?? this.id,
      date: date ?? this.date,
      desc: desc ?? this.desc,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      note: note ?? this.note,
      balance: balance ?? this.balance,
    );
  }
}
