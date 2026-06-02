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
      bool excluded = false,
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
        excluded: excluded,
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
          tx(id: '3', amount: 600130, unmatched: true),
          tx(id: '4', amount: 25),
        ],
        sources: sources,
        categories: categories,
        uncategorized: uncategorized,
      );

      expect(summary.totalSpend, 150);
      expect(summary.unmatchedSpend, 600155);
      expect(summary.unmatchedCount, 2);
      expect(summary.sources.every((s) => s.source.id != ''), isTrue);
    });

    test('orphaned source refs roll into unmatched, not a second row', () {
      final summary = LocalDashboardRepository.summarize(
        label: 'May',
        start: start,
        end: end,
        transactions: [
          tx(id: '1', amount: 100, sourceId: 'card-1', categoryId: 'food'),
          // Source id no longer exists — should not appear as a matched account row.
          tx(id: '2', amount: 130, sourceId: 'deleted-card', categoryId: 'food'),
        ],
        sources: sources,
        categories: categories,
        uncategorized: uncategorized,
      );

      expect(summary.totalSpend, 100);
      expect(summary.unmatchedSpend, 130);
      expect(summary.unmatchedCount, 1);
      expect(summary.sources.length, 1);
      expect(summary.sources.first.source.id, 'card-1');
    });

    test('excluded transactions are omitted from all buckets', () {
      final summary = LocalDashboardRepository.summarize(
        label: 'May',
        start: start,
        end: end,
        transactions: [
          tx(id: '1', amount: 100, sourceId: 'card-1', categoryId: 'food'),
          tx(id: '2', amount: 600000, unmatched: true, excluded: true),
        ],
        sources: sources,
        categories: categories,
        uncategorized: uncategorized,
      );

      expect(summary.totalSpend, 100);
      expect(summary.unmatchedSpend, 0);
      expect(summary.unmatchedCount, 0);
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
      expect(summary.sources.first.source.id, 'card-1');
      expect(summary.sources.first.amount, 140);
      expect(summary.sources.first.transactionCount, 2);
      expect(summary.sources[1].source.id, 'bank-1');
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

    test('isUnmatched treats missing sources as unmatched', () {
      expect(
        LocalDashboardRepository.isUnmatched(
          tx(id: '1', amount: 10, sourceId: 'gone'),
          {'card-1'},
        ),
        isTrue,
      );
      expect(
        LocalDashboardRepository.isUnmatched(
          tx(id: '2', amount: 10, sourceId: 'card-1'),
          {'card-1'},
        ),
        isFalse,
      );
    });

    test('filterSourceTransactions matches summarize unmatched bucket', () {
      final known = sources.map((s) => s.id).toSet();
      final rows = [
        tx(id: '1', amount: 100, sourceId: 'card-1', categoryId: 'food'),
        tx(id: '2', amount: 130, sourceId: 'deleted-card', categoryId: 'food'),
        tx(id: '3', amount: 25, unmatched: true),
        tx(
          id: '4',
          amount: 500,
          sourceId: 'bank-1',
          type: TransactionType.credit,
        ),
        tx(id: '5', amount: 999, sourceId: 'deleted-card', excluded: true),
      ];

      final unmatched = LocalDashboardRepository.filterSourceTransactions(
        transactions: rows,
        paymentSourceId: null,
        knownSourceIds: known,
      );

      expect(unmatched.map((t) => t.id).toList(), ['2', '3']);

      final summary = LocalDashboardRepository.summarize(
        label: 'May',
        start: start,
        end: end,
        transactions: rows,
        sources: sources,
        categories: categories,
        uncategorized: uncategorized,
      );
      expect(summary.unmatchedCount, unmatched.length);
      expect(summary.unmatchedSpend, unmatched.fold(0.0, (s, t) => s + t.amount));
    });

    test('filterCategoryTransactions matches summarize category buckets', () {
      final known = sources.map((s) => s.id).toSet();
      final rows = [
        tx(id: '1', amount: 100, sourceId: 'card-1', categoryId: 'food'),
        tx(id: '2', amount: 40, sourceId: 'card-1', categoryId: 'food'),
        tx(id: '3', amount: 50, sourceId: 'bank-1', categoryId: 'shopping'),
        tx(id: '4', amount: 25, sourceId: 'card-1'),
        tx(id: '5', amount: 130, sourceId: 'deleted-card', categoryId: 'food'),
        tx(
          id: '6',
          amount: 500,
          sourceId: 'bank-1',
          type: TransactionType.credit,
          categoryId: 'food',
        ),
      ];

      final food = LocalDashboardRepository.filterCategoryTransactions(
        transactions: rows,
        categoryId: 'food',
        knownSourceIds: known,
      );

      expect(food.map((t) => t.id).toList(), ['1', '2']);

      final uncategorizedTxs =
          LocalDashboardRepository.filterCategoryTransactions(
        transactions: rows,
        categoryId: 'uncategorized',
        knownSourceIds: known,
      );

      expect(uncategorizedTxs.map((t) => t.id).toList(), ['4']);

      final summary = LocalDashboardRepository.summarize(
        label: 'May',
        start: start,
        end: end,
        transactions: rows,
        sources: sources,
        categories: categories,
        uncategorized: uncategorized,
      );

      final foodBucket = summary.breakdown.firstWhere((b) => b.category.id == 'food');
      expect(foodBucket.transactionCount, food.length);
      expect(foodBucket.amount, food.fold(0.0, (s, t) => s + t.amount));
    });
  });
}
