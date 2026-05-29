import 'package:money_matters/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

final _createdAt = DateTime.parse('2026-05-01T00:00:00Z');

void main() {
  group('PaymentSource', () {
    test('round-trips through JSON', () {
      final source = PaymentSource(
        id: 'ps-1',
        name: 'HDFC Savings',
        type: PaymentSourceType.bank,
        last4: '1234',
        senderHints: ['VK-HDFCBK', 'HDFCBK'],
        createdAt: _createdAt,
      );

      final restored = PaymentSource.fromJson(source.toJson());

      expect(restored.id, source.id);
      expect(restored.name, source.name);
      expect(restored.type, PaymentSourceType.bank);
      expect(restored.last4, '1234');
      expect(restored.senderHints, ['VK-HDFCBK', 'HDFCBK']);
    });

    test('matches instrument hint by last-4', () {
      final source = PaymentSource(
        id: 'ps-1',
        name: 'HDFC Card',
        type: PaymentSourceType.card,
        last4: '4567',
        createdAt: _createdAt,
      );

      expect(source.matchesInstrumentHint('4567'), isTrue);
      expect(source.matchesInstrumentHint('1234'), isFalse);
    });

    test('matches sender hints case-insensitively', () {
      final source = PaymentSource(
        id: 'ps-1',
        name: 'ICICI',
        type: PaymentSourceType.bank,
        senderHints: ['icicib'],
        createdAt: _createdAt,
      );

      expect(source.matchesSender('VM-ICICIB'), isTrue);
      expect(source.matchesSender('VK-HDFCBK'), isFalse);
    });
  });

  group('RawIngest', () {
    test('round-trips through JSON', () {
      final ingest = RawIngest(
        id: 'sha256-key',
        body: 'Rs.500 debited',
        sender: 'VK-HDFCBK',
        receivedAt: DateTime.parse('2026-05-29T14:32:00+05:30'),
        deviceId: 'uuid-1',
        source: 'shortcuts-automation-v1',
        createdAt: DateTime.parse('2026-05-29T14:32:05+05:30'),
        duplicate: true,
      );

      final restored = RawIngest.fromJson(ingest.toJson());

      expect(restored.id, ingest.id);
      expect(restored.body, ingest.body);
      expect(restored.duplicate, isTrue);
    });
  });

  group('Transaction', () {
    test('round-trips through JSON', () {
      final txn = Transaction(
        id: 'txn-1',
        rawIngestId: 'ingest-1',
        amount: 899,
        merchant: 'ZUDIO',
        timestamp: DateTime.parse('2026-05-29T00:00:00+05:30'),
        paymentSourceId: 'ps-1',
        type: TransactionType.debit,
      );

      final restored = Transaction.fromJson(txn.toJson());

      expect(restored.amount, 899);
      expect(restored.merchant, 'ZUDIO');
      expect(restored.type, TransactionType.debit);
      expect(restored.unmatched, isFalse);
    });
  });

  group('Category', () {
    test('matches merchant rules', () {
      const category = Category(
        id: 'cat-food',
        name: 'Food',
        merchantRules: ['SWIGGY', 'ZOMATO'],
      );

      expect(category.matchMerchant('SWIGGY INSTAMART'), 'cat-food');
      expect(category.matchMerchant('ZUDIO'), isNull);
    });

    test('round-trips through JSON', () {
      const category = Category(
        id: 'cat-1',
        name: 'Shopping',
        system: true,
        merchantRules: ['AMAZON'],
      );

      final restored = Category.fromJson(category.toJson());

      expect(restored.name, 'Shopping');
      expect(restored.system, isTrue);
      expect(restored.merchantRules, ['AMAZON']);
    });
  });

  group('ParseJob', () {
    test('round-trips through JSON', () {
      final job = ParseJob(
        id: 'job-1',
        rawIngestId: 'ingest-1',
        status: ParseJobStatus.pending,
        rulesVersion: '1.0.0',
        updatedAt: DateTime.parse('2026-05-29T14:32:00+05:30'),
      );

      final restored = ParseJob.fromJson(job.toJson());

      expect(restored.status, ParseJobStatus.pending);
      expect(restored.rulesVersion, '1.0.0');
    });
  });
}
