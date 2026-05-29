import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/transaction.dart';

/// Transactions needing human review (ambiguous category or unmatched source).
abstract class ReviewRepository {
  Future<List<Transaction>> flaggedTransactions();
  Future<List<Category>> availableCategories();
  Future<void> relabel({
    required String transactionId,
    required String categoryId,
    String? merchantRuleHint,
  });
}
