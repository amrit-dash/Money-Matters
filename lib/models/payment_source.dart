enum PaymentSourceType {
  bank,
  card,
  wallet;

  static PaymentSourceType fromString(String value) {
    return PaymentSourceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentSourceType.bank,
    );
  }
}

class PaymentSource {
  const PaymentSource({
    required this.id,
    required this.name,
    required this.type,
    this.last4,
    this.senderHints = const [],
    required this.createdAt,
  });

  final String id;
  final String name;
  final PaymentSourceType type;
  final String? last4;
  final List<String> senderHints;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        if (last4 != null) 'last4': last4,
        'senderHints': senderHints,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PaymentSource.fromJson(Map<String, dynamic> json) {
    return PaymentSource(
      id: json['id'] as String,
      name: json['name'] as String,
      type: PaymentSourceType.fromString(json['type'] as String? ?? 'bank'),
      last4: json['last4'] as String?,
      senderHints: (json['senderHints'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool matchesInstrumentHint(String? hint) {
    if (hint == null || hint.isEmpty || last4 == null) return false;
    return last4 == hint;
  }

  bool matchesSender(String sender) {
    if (senderHints.isEmpty) return false;
    final normalized = sender.trim().toLowerCase();
    return senderHints.any(
      (hint) => normalized.contains(hint.trim().toLowerCase()),
    );
  }
}
