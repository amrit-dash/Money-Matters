import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

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

/// Structured output of the LLM classification step.
class ClassificationResult {
  const ClassificationResult({
    this.categoryId,
    this.merchantNormalized,
    this.type,
    this.needsUserInput = false,
    this.needsConfig = false,
  });

  /// One of the known category ids (e.g. `food`, `shopping`, `transfer`).
  final String? categoryId;

  /// Cleaned-up merchant name (e.g. raw VPA → "Zepto").
  final String? merchantNormalized;

  /// High-level spend kind reported by the model (shopping, food, transfer…).
  final String? type;

  /// Model is unsure or the spend needs the user to add details.
  final bool needsUserInput;

  /// Backend is missing its API key — caller should fall back to in-app HITL.
  final bool needsConfig;

  factory ClassificationResult.fromMap(Map<String, dynamic> map) {
    return ClassificationResult(
      categoryId: (map['categoryId'] as String?)?.trim().isEmpty ?? true
          ? null
          : map['categoryId'] as String?,
      merchantNormalized: map['merchantNormalized'] as String?,
      type: map['type'] as String?,
      needsUserInput: map['needsUserInput'] as bool? ?? false,
      needsConfig: map['needsConfig'] as bool? ?? false,
    );
  }
}

/// Classifies an already-parsed transaction into a category. Rules run first;
/// this is only invoked for uncategorized or ambiguous transactions.
abstract class TransactionClassifier {
  Future<ClassificationResult?> classify({
    required Transaction transaction,
    String? smsBody,
    List<String> categoryIds = const [],
  });
}

/// Default no-op classifier — leaves transactions for the in-app HITL inbox.
class NoOpTransactionClassifier implements TransactionClassifier {
  const NoOpTransactionClassifier();

  @override
  Future<ClassificationResult?> classify({
    required Transaction transaction,
    String? smsBody,
    List<String> categoryIds = const [],
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
    List<String> categoryIds = const [],
  }) async {
    try {
      final callable = _functions.httpsCallable('classifyTransaction');
      final response = await callable.call<Map<String, dynamic>>({
        'merchant': transaction.merchant,
        'amount': transaction.amount,
        'type': transaction.type.name,
        'smsBody': smsBody,
        'categoryIds': categoryIds,
      });
      final data = Map<String, dynamic>.from(response.data);
      return ClassificationResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('CloudFunctionsClassifier: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('CloudFunctionsClassifier: $e');
      return null;
    }
  }
}
