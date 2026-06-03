import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/core/widgets/transaction_list_filter.dart';
import 'package:money_matters/models/transaction.dart';

void main() {
  group('TransactionListFilter', () {
    final txs = [
      Transaction(
        id: '1',
        rawIngestId: '1',
        amount: 100,
        timestamp: DateTime(2026, 6, 1, 10),
        type: TransactionType.debit,
        categoryId: 'food',
        paymentSourceId: 'bank-1',
      ),
      Transaction(
        id: '2',
        rawIngestId: '2',
        amount: 500,
        timestamp: DateTime(2026, 6, 3, 12),
        type: TransactionType.debit,
        categoryId: 'shopping',
        paymentSourceId: 'card-1',
      ),
      Transaction(
        id: '3',
        rawIngestId: '3',
        amount: 50,
        timestamp: DateTime(2026, 6, 2, 8),
        type: TransactionType.debit,
        categoryId: 'food',
        paymentSourceId: 'bank-1',
      ),
    ];

    test('default sort is latest first', () {
      const filter = TransactionListFilter();
      final result = filter.apply(txs);
      expect(result.map((t) => t.id), ['2', '3', '1']);
    });

    test('sorts oldest first', () {
      const filter = TransactionListFilter(
        sort: TransactionListSort.oldestFirst,
      );
      final result = filter.apply(txs);
      expect(result.map((t) => t.id), ['1', '3', '2']);
    });

    test('sorts by amount high to low', () {
      const filter = TransactionListFilter(
        sort: TransactionListSort.amountHighToLow,
      );
      final result = filter.apply(txs);
      expect(result.map((t) => t.id), ['2', '1', '3']);
    });

    test('filters by payment source', () {
      const filter = TransactionListFilter(
        paymentSourceIds: {'card-1'},
      );
      final result = filter.apply(txs);
      expect(result.map((t) => t.id), ['2']);
      expect(filter.isActive, isTrue);
    });

    test('filters by category', () {
      const filter = TransactionListFilter(
        categoryIds: {'food'},
      );
      final result = filter.apply(txs);
      expect(result.map((t) => t.id), ['3', '1']);
    });

    test('combines filters and sort', () {
      const filter = TransactionListFilter(
        sort: TransactionListSort.amountLowToHigh,
        categoryIds: {'food'},
        paymentSourceIds: {'bank-1'},
      );
      final result = filter.apply(txs);
      expect(result.map((t) => t.id), ['3', '1']);
    });
  });
}
