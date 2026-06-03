import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/category_taxonomy.dart';
import '../models/payment_source.dart';
import '../models/raw_ingest.dart';
import '../models/transaction.dart';
import 'parse_result.dart';

/// Optional LLM gate for ambiguous parses. Default implementation is a no-op.
///
/// This operates at the [ParseResult] level (pre-persist). The richer
/// transaction-level classifier used after parsing is [TransactionClassifier].
abstract class LlmParser {
  Future<ParseResult?> refine(RawIngest ingest, ParseResult rulesResult);
}

/// Returns null so [ParseService] keeps the rules result unchanged.
class NoOpLlmParser implements LlmParser {
  const NoOpLlmParser();

  @override
  Future<ParseResult?> refine(RawIngest ingest, ParseResult rulesResult) async {
    return null;
  }
}

/// Last classify call outcome — for Recovery sync messages and debug logs.
class ClassifierDiagnostics {
  ClassifierDiagnostics._();

  static String? lastError;
  static bool lastNeedsConfig = false;
  static DateTime? lastAttemptAt;
  static int lastSuccessCount = 0;

  static void recordAttempt({
    String? error,
    bool needsConfig = false,
    int successCount = 0,
  }) {
    lastAttemptAt = DateTime.now().toUtc();
    lastError = error;
    lastNeedsConfig = needsConfig;
    lastSuccessCount = successCount;
  }

  /// Clears needs-config backoff so the next sync retries Cloud Functions.
  static void clearNeedsConfigBackoff() {
    lastNeedsConfig = false;
    lastError = null;
  }
}

/// Structured output of the LLM classification step.
class ClassificationResult {
  const ClassificationResult({
    this.categoryId,
    this.merchantNormalized,
    this.subcategoryId,
    this.type,
    this.needsUserInput = false,
    this.needsConfig = false,
    this.categoryConfidence,
    this.paymentSourceId,
    this.paymentSourceConfidence,
    this.userNotes,
    this.shoppingItems = const [],
    this.travelProvider,
    this.transferTo,
    this.suggestedCategoryId,
    this.suggestedCategoryName,
    this.errorMessage,
  });

  /// One of the known category ids (e.g. `food`, `shopping`, `transfer`).
  final String? categoryId;

  /// Cleaned-up merchant display name extracted from SMS (e.g. raw VPA → "Zepto").
  final String? merchantNormalized;

  /// Optional refine under [categoryId] (e.g. bills → rent).
  final String? subcategoryId;

  /// High-level spend kind reported by the model (shopping, food, transfer…).
  final String? type;

  /// Model is unsure or the spend needs the user to add details.
  final bool needsUserInput;

  /// Backend is missing its API key — caller should fall back to in-app HITL.
  final bool needsConfig;

  /// Model confidence for [categoryId] in 0.0–1.0 (auto-apply when ≥ 0.8).
  final double? categoryConfidence;

  /// Matched saved bank/card id when the model is confident from SMS context.
  final String? paymentSourceId;

  /// Model confidence for [paymentSourceId] in 0.0–1.0.
  final double? paymentSourceConfidence;

  /// Short user-facing note from the model (e.g. "weekly groceries").
  final String? userNotes;

  /// Optional line items when the spend is clearly a shopping trip.
  final List<String> shoppingItems;

  /// Ride/travel provider when obvious from SMS (e.g. Uber, Ola).
  final String? travelProvider;

  /// Transfer recipient or destination when category is transfer.
  final String? transferTo;

  /// Proposed new category slug when none of the allowed ids fit.
  final String? suggestedCategoryId;

  /// Human-readable label for [suggestedCategoryId].
  final String? suggestedCategoryName;

  /// Callable/network failure — distinct from [needsConfig] (missing backend key).
  final String? errorMessage;

  static const paymentSourceConfidenceThreshold = 0.85;

  /// Pipeline auto-applies category only at or above this threshold.
  static const categoryConfidenceThreshold = 0.8;

  factory ClassificationResult.fromMap(Map<String, dynamic> map) {
    final rawCatConfidence = map['categoryConfidence'];
    final rawConfidence = map['paymentSourceConfidence'];
    final rawItems = map['shoppingItems'];
    List<String> items = const [];
    if (rawItems is List) {
      items = rawItems
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return ClassificationResult(
      categoryId: (map['categoryId'] as String?)?.trim().isEmpty ?? true
          ? null
          : map['categoryId'] as String?,
      merchantNormalized: _parseOptionalString(map['merchantNormalized']),
      subcategoryId: _parseOptionalString(map['subcategoryId']),
      type: map['type'] as String?,
      needsUserInput: map['needsUserInput'] as bool? ?? false,
      needsConfig: map['needsConfig'] as bool? ?? false,
      categoryConfidence: rawCatConfidence is num
          ? rawCatConfidence.toDouble()
          : null,
      paymentSourceId: (map['paymentSourceId'] as String?)?.trim().isEmpty ?? true
          ? null
          : map['paymentSourceId'] as String?,
      paymentSourceConfidence: rawConfidence is num
          ? rawConfidence.toDouble()
          : null,
      userNotes: (map['userNotes'] as String?)?.trim().isEmpty ?? true
          ? null
          : (map['userNotes'] as String?)?.trim(),
      shoppingItems: items,
      travelProvider: _parseOptionalString(map['travelProvider']),
      transferTo: _parseOptionalString(map['transferTo']),
      suggestedCategoryId: _parseOptionalString(map['suggestedCategoryId']),
      suggestedCategoryName: _parseOptionalString(map['suggestedCategoryName']),
    );
  }

  static String? _parseOptionalString(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Classifies an already-parsed transaction into a category. Rules run first;
/// this is only invoked for uncategorized or ambiguous transactions.
abstract class TransactionClassifier {
  Future<ClassificationResult?> classify({
    required Transaction transaction,
    String? smsBody,
    String? smsSender,
    List<String> categoryIds = const [],
    String? selectedCategoryId,
    String? userDescription,
    Map<String, List<String>> subcategoryTaxonomy = const {},
    List<PaymentSource> paymentSources = const [],
    bool includePaymentSources = true,
    bool includeSubcategoryTaxonomy = true,
  });
}

/// Default no-op classifier — leaves transactions for the in-app HITL inbox.
class NoOpTransactionClassifier implements TransactionClassifier {
  const NoOpTransactionClassifier();

  @override
  Future<ClassificationResult?> classify({
    required Transaction transaction,
    String? smsBody,
    String? smsSender,
    List<String> categoryIds = const [],
    String? selectedCategoryId,
    String? userDescription,
    Map<String, List<String>> subcategoryTaxonomy = const {},
    List<PaymentSource> paymentSources = const [],
    bool includePaymentSources = true,
    bool includeSubcategoryTaxonomy = true,
  }) async =>
      null;
}

/// Calls the `classifyTransaction` Cloud Function (Gemini-backed).
///
/// Region must match the deployed function (`asia-south1`). On any error or
/// when the backend reports `needsConfig`, the caller keeps the transaction in
/// the in-app "Needs your input" inbox — the app never blocks on the LLM.
class CloudFunctionsClassifier implements TransactionClassifier {
  CloudFunctionsClassifier({
    FirebaseFunctions? functions,
    this.region = 'asia-south1',
  }) : _functions = functions ?? FirebaseFunctions.instanceFor(region: region);

  final FirebaseFunctions _functions;
  final String region;

  @override
  Future<ClassificationResult?> classify({
    required Transaction transaction,
    String? smsBody,
    String? smsSender,
    List<String> categoryIds = const [],
    String? selectedCategoryId,
    String? userDescription,
    Map<String, List<String>> subcategoryTaxonomy = const {},
    List<PaymentSource> paymentSources = const [],
    bool includePaymentSources = true,
    bool includeSubcategoryTaxonomy = true,
  }) async {
    try {
      final taxonomy = includeSubcategoryTaxonomy
          ? (subcategoryTaxonomy.isEmpty
              ? subcategoryTaxonomyForLlm()
              : subcategoryTaxonomy)
          : const <String, List<String>>{};
      final sources = includePaymentSources ? paymentSources : const <PaymentSource>[];
      final callable = _functions.httpsCallable('classifyTransaction');
      final response = await callable.call<Map<String, dynamic>>({
        'merchant': transaction.merchant,
        'amount': transaction.amount,
        'type': transaction.type.name,
        'smsBody': smsBody,
        if (smsSender != null && smsSender.isNotEmpty) 'sender': smsSender,
        'categoryIds': categoryIds,
        if (selectedCategoryId != null && selectedCategoryId.isNotEmpty) ...{
          'selectedCategoryId': selectedCategoryId,
          'hintCategoryId': selectedCategoryId,
        },
        if (userDescription != null && userDescription.trim().isNotEmpty)
          'userDescription': userDescription.trim(),
        if (taxonomy.isNotEmpty) 'subcategoryTaxonomy': taxonomy,
        if (sources.isNotEmpty)
          'paymentSources': sources
              .map(
                (s) => {
                  'id': s.id,
                  'displayName': s.name,
                  'type': s.type.name,
                  'senderHints': s.senderHints,
                  if (s.last4 != null) 'last4': s.last4,
                },
              )
              .toList(),
      });
      final data = Map<String, dynamic>.from(response.data);
      final result = ClassificationResult.fromMap(data);
      if (result.needsConfig) {
        ClassifierDiagnostics.recordAttempt(
          needsConfig: true,
          error: 'LLM not configured — enable in Profile → Agent settings',
        );
        debugPrint(
          'CloudFunctionsClassifier: needsConfig — configure Agent settings '
          'or firebase functions:secrets:set GEMINI_API_KEY',
        );
      }
      return result;
    } on FirebaseFunctionsException catch (e) {
      final msg = '${e.code}: ${e.message ?? "classify failed"}';
      debugPrint('CloudFunctionsClassifier: $msg');
      ClassifierDiagnostics.recordAttempt(error: msg);
      return ClassificationResult(errorMessage: msg);
    } catch (e) {
      debugPrint('CloudFunctionsClassifier: $e');
      ClassifierDiagnostics.recordAttempt(error: e.toString());
      return ClassificationResult(errorMessage: e.toString());
    }
  }
}
