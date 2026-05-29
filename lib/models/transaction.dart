enum TransactionType {
  debit,
  credit;

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TransactionType.debit,
    );
  }
}

class Transaction {
  const Transaction({
    this.id,
    required this.rawIngestId,
    required this.amount,
    this.currency = 'INR',
    this.merchant,
    required this.timestamp,
    this.categoryId,
    this.paymentSourceId,
    this.unmatched = false,
    this.ambiguous = false,
    required this.type,
  });

  final String? id;
  final String rawIngestId;
  final double amount;
  final String currency;
  final String? merchant;
  final DateTime timestamp;
  final String? categoryId;
  final String? paymentSourceId;
  final bool unmatched;
  final bool ambiguous;
  final TransactionType type;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'rawIngestId': rawIngestId,
        'amount': amount,
        'currency': currency,
        if (merchant != null) 'merchant': merchant,
        'timestamp': timestamp.toIso8601String(),
        if (categoryId != null) 'categoryId': categoryId,
        if (paymentSourceId != null) 'paymentSourceId': paymentSourceId,
        'unmatched': unmatched,
        'ambiguous': ambiguous,
        'type': type.name,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String?,
      rawIngestId: json['rawIngestId'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      merchant: json['merchant'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      categoryId: json['categoryId'] as String?,
      paymentSourceId: json['paymentSourceId'] as String?,
      unmatched: json['unmatched'] as bool? ?? false,
      ambiguous: json['ambiguous'] as bool? ?? false,
      type: TransactionType.fromString(json['type'] as String? ?? 'debit'),
    );
  }

  Transaction copyWith({
    String? id,
    String? rawIngestId,
    double? amount,
    String? currency,
    String? merchant,
    DateTime? timestamp,
    String? categoryId,
    String? paymentSourceId,
    bool? unmatched,
    bool? ambiguous,
    TransactionType? type,
  }) {
    return Transaction(
      id: id ?? this.id,
      rawIngestId: rawIngestId ?? this.rawIngestId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      merchant: merchant ?? this.merchant,
      timestamp: timestamp ?? this.timestamp,
      categoryId: categoryId ?? this.categoryId,
      paymentSourceId: paymentSourceId ?? this.paymentSourceId,
      unmatched: unmatched ?? this.unmatched,
      ambiguous: ambiguous ?? this.ambiguous,
      type: type ?? this.type,
    );
  }
}
