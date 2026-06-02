import 'dart:convert';

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

/// Who/what assigned the current category on a transaction.
enum ClassifiedBy {
  rules,
  llm,
  user;

  static ClassifiedBy? fromString(String? value) {
    if (value == null) return null;
    for (final e in ClassifiedBy.values) {
      if (e.name == value) return e;
    }
    return null;
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
    this.subcategoryId,
    this.paymentSourceId,
    this.unmatched = false,
    this.ambiguous = false,
    this.excluded = false,
    required this.type,
    this.needsClassification = false,
    this.merchantNormalized,
    this.userNotes,
    this.shoppingItems = const [],
    this.travelProvider,
    this.transferTo,
    this.classifiedBy,
  });

  final String? id;
  final String rawIngestId;
  final double amount;
  final String currency;
  final String? merchant;
  final DateTime timestamp;
  final String? categoryId;

  /// Optional refine under [categoryId] (e.g. bills → rent, food → delivery).
  final String? subcategoryId;

  final String? paymentSourceId;
  final bool unmatched;
  final bool ambiguous;

  /// User-marked false positive (promo, not a real spend) — hidden from totals.
  final bool excluded;

  final TransactionType type;

  /// True when the transaction still needs a category from the user or LLM.
  /// Drives the in-app "Needs your input" inbox and FCM classify prompts.
  final bool needsClassification;

  /// LLM/heuristic-normalized merchant name (e.g. raw VPA → "Zepto").
  final String? merchantNormalized;

  /// Free-text note the user adds when classifying (e.g. "groceries").
  final String? userNotes;

  /// Optional shopping-list items captured during the classify flow.
  final List<String> shoppingItems;

  /// Optional ride/travel provider (e.g. Uber) from classify flow.
  final String? travelProvider;

  /// Transfer recipient or destination when category is transfer.
  final String? transferTo;

  /// Provenance of the current category: rules, llm, or user.
  final ClassifiedBy? classifiedBy;

  /// Display name preferring the normalized merchant.
  String? get displayMerchant => merchantNormalized ?? merchant;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'rawIngestId': rawIngestId,
        'amount': amount,
        'currency': currency,
        if (merchant != null) 'merchant': merchant,
        'timestamp': timestamp.toIso8601String(),
        if (categoryId != null) 'categoryId': categoryId,
        if (subcategoryId != null) 'subcategoryId': subcategoryId,
        if (paymentSourceId != null) 'paymentSourceId': paymentSourceId,
        'unmatched': unmatched,
        'ambiguous': ambiguous,
        'excluded': excluded,
        'type': type.name,
        'needsClassification': needsClassification,
        if (merchantNormalized != null) 'merchantNormalized': merchantNormalized,
        if (userNotes != null) 'userNotes': userNotes,
        if (shoppingItems.isNotEmpty) 'shoppingItems': shoppingItems,
        if (travelProvider != null) 'travelProvider': travelProvider,
        if (transferTo != null) 'transferTo': transferTo,
        if (classifiedBy != null) 'classifiedBy': classifiedBy!.name,
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
      subcategoryId: json['subcategoryId'] as String?,
      paymentSourceId: json['paymentSourceId'] as String?,
      unmatched: json['unmatched'] as bool? ?? false,
      ambiguous: json['ambiguous'] as bool? ?? false,
      excluded: json['excluded'] as bool? ?? false,
      type: TransactionType.fromString(json['type'] as String? ?? 'debit'),
      needsClassification: json['needsClassification'] as bool? ?? false,
      merchantNormalized: json['merchantNormalized'] as String?,
      userNotes: json['userNotes'] as String?,
      shoppingItems: (json['shoppingItems'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      travelProvider: json['travelProvider'] as String?,
      transferTo: json['transferTo'] as String?,
      classifiedBy: ClassifiedBy.fromString(json['classifiedBy'] as String?),
    );
  }

  /// Maps a `transactions` table row (snake_case) to a [Transaction].
  factory Transaction.fromSqlite(Map<String, dynamic> row) {
    final rawItems = row['shopping_items'] as String?;
    List<String> items = const [];
    if (rawItems != null && rawItems.isNotEmpty) {
      try {
        items = (jsonDecode(rawItems) as List<dynamic>)
            .map((e) => e.toString())
            .toList();
      } catch (_) {
        items = const [];
      }
    }
    return Transaction(
      id: row['id'] as String?,
      rawIngestId: row['raw_ingest_id'] as String? ?? '',
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      currency: row['currency'] as String? ?? 'INR',
      merchant: row['merchant'] as String?,
      timestamp: DateTime.parse(row['timestamp'] as String),
      categoryId: row['category_id'] as String?,
      subcategoryId: row['subcategory_id'] as String?,
      paymentSourceId: row['payment_source_id'] as String?,
      unmatched: (row['unmatched'] as int? ?? 0) == 1,
      ambiguous: (row['ambiguous'] as int? ?? 0) == 1,
      excluded: (row['excluded'] as int? ?? 0) == 1,
      type: TransactionType.fromString(row['type'] as String? ?? 'debit'),
      needsClassification: (row['needs_classification'] as int? ?? 0) == 1,
      merchantNormalized: row['merchant_normalized'] as String?,
      userNotes: row['user_notes'] as String?,
      shoppingItems: items,
      travelProvider: row['travel_provider'] as String?,
      transferTo: row['transfer_to'] as String?,
      classifiedBy: ClassifiedBy.fromString(row['classified_by'] as String?),
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
    String? subcategoryId,
    String? paymentSourceId,
    bool? unmatched,
    bool? ambiguous,
    bool? excluded,
    TransactionType? type,
    bool? needsClassification,
    String? merchantNormalized,
    String? userNotes,
    List<String>? shoppingItems,
    String? travelProvider,
    String? transferTo,
    ClassifiedBy? classifiedBy,
  }) {
    return Transaction(
      id: id ?? this.id,
      rawIngestId: rawIngestId ?? this.rawIngestId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      merchant: merchant ?? this.merchant,
      timestamp: timestamp ?? this.timestamp,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      paymentSourceId: paymentSourceId ?? this.paymentSourceId,
      unmatched: unmatched ?? this.unmatched,
      ambiguous: ambiguous ?? this.ambiguous,
      excluded: excluded ?? this.excluded,
      type: type ?? this.type,
      needsClassification: needsClassification ?? this.needsClassification,
      merchantNormalized: merchantNormalized ?? this.merchantNormalized,
      userNotes: userNotes ?? this.userNotes,
      shoppingItems: shoppingItems ?? this.shoppingItems,
      travelProvider: travelProvider ?? this.travelProvider,
      transferTo: transferTo ?? this.transferTo,
      classifiedBy: classifiedBy ?? this.classifiedBy,
    );
  }
}
