import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/features/dashboard/local_dashboard_repository.dart';
import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';

void main() {
  group('LocalDashboardRepository.summarize', () {
    final start = DateTime(2026, 5, 1);
    final end = DateTime(2026, 5, 31, 23, 59, 59);

    final sources = [
      PaymentSource(
        id: 'card-1',
        name: 'HDFC Credit',
        type: PaymentSourceType.card,
        last4: '4567',
        createdAt: DateTime(2026),
      ),
      PaymentSource(
        id: 'bank-1',
        name: 'Federal Bank',
        type: PaymentSourceType.bank,
        last4: '1234',
        createdAt: DateTime(2026),
      ),
    ];

    const categories = [
      Category(id: 'food', name: 'Food & Dining'),
      Category(id: 'shopping', name: 'Shopping'),
    ];

    const uncategorized = Category(id: 'uncategorized', name: 'Uncategorized');

    Transaction tx({
      required String id,
      required double amount,
      String? sourceId,
      bool unmatched = false,
      String? categoryId,
      TransactionType type = TransactionType.debit,
    }) {
      return Transaction(
        id: id,
        rawIngestId: id,
        amount: amount,
        timestamp: DateTime(2026, 5, 10),
        type: type,
        paymentSourceId: sourceId,
        unmatched: unmatched,
        categoryId: categoryId,
      );
    }

    test('excludes unmatched debits from total spend and counts them apart', () {
      final summary = LocalDashboardRepository.summarize(
        label: 'May',
        start: start,
        end: end,
        transactions: [
          tx(id: '1', amount: 100, sourceId: 'card-1', categoryId: 'food'),
          tx(id: '2', amount: 50, sourceId: 'bank-1', categoryId: 'shopping'),
          // Unmatched: no saved bank/card matched (e.g. promo leak / unknown).
          tx(id: '3', amount: 600130, unmatched: true),
          tx(id: '4', amount: 25), // null source also counts as unmatched
        ],
        sources: sources,
        categories: categories,
        uncategorized: uncategorized,
      );

      expect(summary.totalSpend, 150);
      expect(summary.unmatchedSpend, 600155);
      expect(summary.unmatchedCount, 2);
    });

    test('groups matched spend per payment source', () {
      final summary = LocalDashboardRepository.summarize(
        label: 'May',
        start: start,
        end: end,
        transactions: [
          tx(id: '1', amount: 100, sourceId: 'card-1', categoryId: 'food'),
          tx(id: '2', amount: 40, sourceId: 'card-1', categoryId: 'food'),
          tx(id: '3', amount: 50, sourceId: 'bank-1', categoryId: 'shopping'),
        ],
        sources: sources,
        categories: categories,
        uncategorized: uncategorized,
      );

      expect(summary.sources.length, 2);
      // Sorted by amount desc → card-1 first.
      expect(summary.sources.first.source?.id, 'card-1');
      expect(summary.sources.first.amount, 140);
      expect(summary.sources.first.transactionCount, 2);
      expect(summary.sources[1].source?.id, 'bank-1');
      expect(summary.sources[1].amount, 50);
    });

    test('credits add to income, not spend', () {
      final summary = LocalDashboardRepository.summarize(
        label: 'May',
        start: start,
        end: end,
        transactions: [
          tx(id: '1', amount: 100, sourceId: 'card-1', categoryId: 'food'),
          tx(
            id: '2',
            amount: 5000,
            sourceId: 'bank-1',
            type: TransactionType.credit,
          ),
        ],
        sources: sources,
        categories: categories,
        uncategorized: uncategorized,
      );

      expect(summary.totalSpend, 100);
      expect(summary.totalIncome, 5000);
      expect(summary.net, 4900);
    });
  });
}
