import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/transaction.dart';

/// Result of classifying a transaction from the in-app HITL flow.
class ClassifyInput {
  const ClassifyInput({
    required this.categoryId,
    this.userNotes,
    this.shoppingItems = const [],
    this.saveMerchantRule = false,
  });

  final String categoryId;
  final String? userNotes;
  final List<String> shoppingItems;
  final bool saveMerchantRule;
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
}
