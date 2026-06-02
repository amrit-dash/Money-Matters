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
    this.merchantHints = const [],
    this.bodyPatterns = const [],
    required this.createdAt,
  });

  final String id;
  final String name;
  final PaymentSourceType type;
  final String? last4;
  final List<String> senderHints;

  /// User-learned merchant substrings correlated with this account.
  final List<String> merchantHints;

  /// User-learned SMS body substrings (e.g. bank footer) for this account.
  final List<String> bodyPatterns;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        if (last4 != null) 'last4': last4,
        'senderHints': senderHints,
        'merchantHints': merchantHints,
        'bodyPatterns': bodyPatterns,
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
      merchantHints: (json['merchantHints'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      bodyPatterns: (json['bodyPatterns'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool matchesInstrumentHint(String? hint) {
    if (hint == null || hint.isEmpty || last4 == null) return false;
    return normalizeLast4(last4) == normalizeLast4(hint);
  }

  bool matchesSender(String sender) {
    if (senderHints.isEmpty) return false;
    final normalized = sender.trim().toLowerCase();
    return senderHints.any(
      (hint) => normalized.contains(hint.trim().toLowerCase()),
    );
  }

  /// Matches bank name in SMS body (e.g. "-Federal Bank" footer on manual paste).
  bool matchesBody(String body) {
    final normalizedName = name.trim().toLowerCase();
    if (normalizedName.isEmpty) return false;
    if (body.toLowerCase().contains(normalizedName)) return true;
    return matchesBodyPattern(body);
  }

  /// User-learned body substrings from past manual account assignments.
  bool matchesBodyPattern(String body) {
    if (bodyPatterns.isEmpty) return false;
    final normalized = body.toLowerCase();
    return bodyPatterns.any(
      (pattern) => pattern.isNotEmpty && normalized.contains(pattern.toLowerCase()),
    );
  }

  /// User-learned merchant substrings from past manual account assignments.
  bool matchesMerchant(String? merchant) {
    if (merchant == null || merchant.isEmpty || merchantHints.isEmpty) {
      return false;
    }
    final upper = merchant.toUpperCase();
    return merchantHints.any(
      (hint) => hint.isNotEmpty && upper.contains(hint.toUpperCase()),
    );
  }
}

/// Strips non-digits and compares the trailing four digits (e.g. "XX 1234" → "1234").
String normalizeLast4(String? value) {
  if (value == null || value.isEmpty) return '';
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.length <= 4) return digits.padLeft(4, '0');
  return digits.substring(digits.length - 4);
}

/// Rules-first payment source resolution from SMS sender and body text.
///
/// User-learned [PaymentSource.merchantHints] and [PaymentSource.bodyPatterns]
/// are checked before generic last4/sender/name matching.
String? matchPaymentSourceFromIngest({
  required String sender,
  required String body,
  String? instrumentLast4,
  String? merchant,
  required List<PaymentSource> sources,
}) {
  if (sources.isEmpty) return null;

  if (merchant != null && merchant.isNotEmpty) {
    for (final source in sources) {
      if (source.matchesMerchant(merchant)) {
        return source.id;
      }
    }
  }

  for (final source in sources) {
    if (source.matchesBodyPattern(body)) {
      return source.id;
    }
  }

  if (instrumentLast4 != null) {
    for (final source in sources) {
      if (source.matchesInstrumentHint(instrumentLast4)) {
        return source.id;
      }
    }
  }

  for (final source in sources) {
    if (source.matchesSender(sender)) {
      return source.id;
    }
  }

  for (final source in sources) {
    if (source.matchesBody(body)) {
      return source.id;
    }
  }

  return null;
}
