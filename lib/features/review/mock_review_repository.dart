import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/transaction.dart';

import 'review_repository.dart';

/// Sample flagged rows until parse pipeline is wired.
class MockReviewRepository implements ReviewRepository {
  final List<Transaction> _transactions = [
    Transaction(
      id: 'tx-1',
      rawIngestId: 'ing-1',
      amount: 899,
      currency: 'INR',
      merchant: 'ZUDIO',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      categoryId: null,
      paymentSourceId: 'card-4567',
      unmatched: false,
      ambiguous: true,
      type: TransactionType.debit,
    ),
    Transaction(
      id: 'tx-2',
      rawIngestId: 'ing-2',
      amount: 2500,
      currency: 'INR',
      merchant: 'AMRIT K',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      categoryId: null,
      paymentSourceId: null,
      unmatched: true,
      ambiguous: true,
      type: TransactionType.debit,
    ),
    Transaction(
      id: 'tx-3',
      rawIngestId: 'ing-3',
      amount: 150,
      currency: 'INR',
      merchant: 'SWIGGY',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      categoryId: 'food',
      paymentSourceId: 'card-4567',
      unmatched: false,
      ambiguous: true,
      type: TransactionType.debit,
    ),
  ];

  final List<Category> _categories = [
    Category(id: 'food', name: 'Food & Dining', system: true),
    Category(id: 'transport', name: 'Transport', system: true),
    Category(id: 'shopping', name: 'Shopping', system: true),
    Category(id: 'bills', name: 'Bills & Utilities', system: true),
    Category(id: 'upi', name: 'UPI / Transfers', system: true),
    Category(id: 'other', name: 'Other', system: false),
  ];

  @override
  Future<List<Transaction>> flaggedTransactions() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _transactions
        .where((t) => t.ambiguous || t.unmatched)
        .toList(growable: false);
  }

  @override
  Future<List<Category>> availableCategories() async => _categories;

  @override
  Future<void> relabel({
    required String transactionId,
    required String categoryId,
    String? merchantRuleHint,
  }) async {
    final index = _transactions.indexWhere((t) => t.id == transactionId);
    if (index < 0) return;
    final old = _transactions[index];
    _transactions[index] = Transaction(
      id: old.id,
      rawIngestId: old.rawIngestId,
      amount: old.amount,
      currency: old.currency,
      merchant: old.merchant,
      timestamp: old.timestamp,
      categoryId: categoryId,
      paymentSourceId: old.paymentSourceId,
      unmatched: old.unmatched,
      ambiguous: false,
      type: old.type,
    );
  }
}
