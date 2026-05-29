import 'package:money_matters/models/models.dart';
import 'package:money_matters/parse/parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RulesParser', () {
    const parser = RulesParser();

    RawIngest sampleIngest(String body, {String sender = 'VK-HDFCBK'}) {
      return RawIngest(
        id: 'ingest-1',
        body: body,
        sender: sender,
        receivedAt: DateTime.parse('2026-05-29T14:32:00+05:30'),
        deviceId: 'device-1',
        source: 'shortcuts-automation-v1',
        createdAt: DateTime.parse('2026-05-29T14:32:00+05:30'),
      );
    }

    test('AE3: classifies credit card bill due as billing reminder', () {
      final result = parser.parse(sampleIngest(
        'Your HDFC Bank credit card bill due on 05-Jun. Min due Rs.500. Pay now.',
      ));

      expect(result.classification, IngestClassification.billingReminder);
      expect(result.candidate, isNull);
    });

    test('AE4: parses HDFC debit with amount, merchant, and last-4', () {
      final result = parser.parse(sampleIngest(
        'Rs.899 debited from A/c **4567 at ZUDIO on 29-05-26. Avl bal Rs.12,000.',
      ));

      expect(result.classification, IngestClassification.transaction);
      expect(result.candidate, isNotNull);
      expect(result.candidate!.amount, 899);
      expect(result.candidate!.merchant, 'ZUDIO');
      expect(result.candidate!.instrumentLast4, '4567');
      expect(result.candidate!.type, TransactionType.debit);
      expect(result.candidate!.ambiguous, isFalse);
    });

    test('parses HDFC credit card spend SMS', () {
      final result = parser.parse(sampleIngest(
        'Thank you for using HDFC Bank Credit Card ending 4567 for INR 1,250.00 at SWIGGY on 29-05-26.',
      ));

      expect(result.classification, IngestClassification.transaction);
      expect(result.candidate!.amount, 1250);
      expect(result.candidate!.merchant, 'SWIGGY');
      expect(result.candidate!.instrumentLast4, '4567');
    });

    test('parses ICICI debit with merchant colon format', () {
      final result = parser.parse(
        sampleIngest(
          'ICICI Bank Acct XX123 debited for Rs 500.00 on 29-May-26; Merchant: SWIGGY. Avl Bal Rs 10,000.',
          sender: 'VM-ICICIB',
        ),
      );

      expect(result.classification, IngestClassification.transaction);
      expect(result.candidate!.amount, 500);
      expect(result.candidate!.merchant, 'SWIGGY');
      expect(result.candidate!.instrumentLast4, '0123');
      expect(result.candidate!.type, TransactionType.debit);
    });

    test('AE8: flags UPI person payment as ambiguous', () {
      final result = parser.parse(sampleIngest(
        'Rs.500 debited from A/c **1234 for UPI/AMRIT K/paytm/ on 29-05-26.',
      ));

      expect(result.classification, IngestClassification.transaction);
      expect(result.candidate!.amount, 500);
      expect(result.candidate!.merchant, 'AMRIT K');
      expect(result.candidate!.ambiguous, isTrue);
    });

    test('classifies promo SMS without creating transaction', () {
      final result = parser.parse(sampleIngest(
        'Congratulations! Pre-approved personal loan offer up to Rs.5,00,000. Apply now.',
      ));

      expect(result.classification, IngestClassification.promo);
      expect(result.candidate, isNull);
    });

    test('parses credited refund as credit transaction', () {
      final result = parser.parse(sampleIngest(
        'INR 299.00 credited to A/c **4567 on 29-05-26. Refund from AMAZON.',
      ));

      expect(result.classification, IngestClassification.transaction);
      expect(result.candidate!.type, TransactionType.credit);
      expect(result.candidate!.amount, 299);
    });

    test('extracts UPI VPA hint when present', () {
      final result = parser.parse(sampleIngest(
        'Rs.200 debited from A/c **1234. UPI/amrit@paytm/merchant on 29-05-26.',
      ));

      expect(result.candidate!.upiHint, 'amrit@paytm');
    });
  });

  group('ParseService', () {
    late ParseService service;

    setUp(() {
      service = ParseService();
    });

    RawIngest sampleIngest(String body) {
      return RawIngest(
        id: 'ingest-ae4',
        body: body,
        sender: 'VK-HDFCBK',
        receivedAt: DateTime.parse('2026-05-29T14:32:00+05:30'),
        deviceId: 'device-1',
        source: 'shortcuts-automation-v1',
        createdAt: DateTime.parse('2026-05-29T14:32:00+05:30'),
      );
    }

    test('AE4: links transaction to registered payment source by last-4', () async {
      final sources = [
        PaymentSource(
          id: 'card-zudio',
          name: 'HDFC Credit',
          type: PaymentSourceType.card,
          last4: '4567',
          senderHints: ['hdfcbk'],
          createdAt: DateTime.parse('2026-05-01T00:00:00Z'),
        ),
      ];

      final outcome = await service.parse(
        sampleIngest(
          'Rs.899 debited from A/c **4567 at ZUDIO on 29-05-26.',
        ),
        paymentSources: sources,
      );

      expect(outcome.transaction, isNotNull);
      expect(outcome.transaction!.amount, 899);
      expect(outcome.transaction!.merchant, 'ZUDIO');
      expect(outcome.transaction!.paymentSourceId, 'card-zudio');
      expect(outcome.transaction!.unmatched, isFalse);
    });

    test('AE3: billing reminder produces no transaction row', () async {
      final outcome = await service.parse(
        sampleIngest('Your credit card bill due on 05-Jun. Pay minimum Rs.500.'),
      );

      expect(outcome.result.classification, IngestClassification.billingReminder);
      expect(outcome.transaction, isNull);
    });

    test('AE5: unknown instrument marks transaction unmatched', () async {
      final outcome = await service.parse(
        sampleIngest(
          'Rs.750 debited from wallet XX9999 at UNKNOWN MERCHANT on 29-05-26.',
        ),
        paymentSources: const [],
      );

      expect(outcome.transaction, isNotNull);
      expect(outcome.transaction!.unmatched, isTrue);
    });

    test('AE8: ambiguous UPI payment flagged on transaction', () async {
      final outcome = await service.parse(
        sampleIngest(
          'Rs.500 debited from A/c **1234 for UPI/AMRIT K/paytm/ on 29-05-26.',
        ),
      );

      expect(outcome.transaction!.ambiguous, isTrue);
      expect(outcome.transaction!.merchant, 'AMRIT K');
    });

    test('promo SMS skipped without transaction', () async {
      final outcome = await service.parse(
        sampleIngest(
          'Limited time offer! Get 10% cashback. Download our app today.',
        ),
      );

      expect(outcome.result.classification, IngestClassification.promo);
      expect(outcome.transaction, isNull);
    });

    test('NoOpLlmParser leaves rules result unchanged', () async {
      final serviceWithNoOp = ParseService(llmParser: const NoOpLlmParser());
      final ingest = sampleIngest(
        'Rs.899 debited from A/c **4567 at ZUDIO on 29-05-26.',
      );

      final outcome = await serviceWithNoOp.parse(ingest);

      expect(outcome.result.isTransaction, isTrue);
      expect(outcome.transaction!.amount, 899);
    });
  });
}
