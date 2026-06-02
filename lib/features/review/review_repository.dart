import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/transaction.dart';

/// Result of classifying a transaction from the in-app HITL flow.
class ClassifyInput {
  const ClassifyInput({
    required this.categoryId,
    this.userNotes,
    this.shoppingItems = const [],
    this.travelProvider,
    this.saveMerchantRule = false,
    this.paymentSourceId,
    this.merchantNormalized,
  });

  final String categoryId;
  final String? userNotes;
  final List<String> shoppingItems;
  final String? travelProvider;
  final bool saveMerchantRule;

  /// When set, links an unmatched transaction to a saved bank/card.
  final String? paymentSourceId;

  /// Display merchant override from user or AI reclassify.
  final String? merchantNormalized;
}

/// Transactions needing human review (uncategorized, ambiguous, or unmatched).
abstract class ReviewRepository {
  Future<List<Transaction>> flaggedTransactions();
  Future<List<Category>> availableCategories();
  Future<Transaction?> transactionById(String id);

  /// Count of items in the "Needs your input" inbox (for badges).
  Future<int> needsInputCount();

  /// Applies a user classification: category + optional notes / shopping items.
  Future<void> classify({
    required Transaction transaction,
    required ClassifyInput input,
  });

  /// Updates only the linked bank/card for an existing transaction.
  Future<void> updatePaymentSource({
    required String transactionId,
    required String paymentSourceId,
  });

  /// Legacy single-field relabel (category only). Delegates to [classify].
  Future<void> relabel({
    required String transactionId,
    required String categoryId,
    String? merchantRuleHint,
  });

  /// Marks a false-positive transaction (promo, not real spend) as excluded.
  Future<void> excludeTransaction(String transactionId);

  /// Permanently removes a transaction locally and from Firestore when synced.
  Future<void> deleteTransaction(String transactionId);

  /// Persists an AI-suggested classification without marking as user-classified.
  Future<void> persistAiClassification(Transaction transaction);
}
