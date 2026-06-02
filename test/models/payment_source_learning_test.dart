import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/models/payment_source.dart';

final _createdAt = DateTime.parse('2026-05-01T00:00:00Z');

PaymentSource _source({
  String id = 'ps-hdfc',
  String? last4,
  List<String> senderHints = const [],
  List<String> merchantHints = const [],
  List<String> bodyPatterns = const [],
}) {
  return PaymentSource(
    id: id,
    name: 'HDFC Savings',
    type: PaymentSourceType.bank,
    last4: last4,
    senderHints: senderHints,
    merchantHints: merchantHints,
    bodyPatterns: bodyPatterns,
    createdAt: _createdAt,
  );
}

void main() {
  group('matchPaymentSourceFromIngest learned rules', () {
    test('prefers user-learned merchant hint over generic last4', () {
      final learned = _source(merchantHints: ['LOCAL CAFE']);
      final other = _source(
        id: 'ps-other',
        last4: '1234',
      );

      final match = matchPaymentSourceFromIngest(
        sender: 'VK-HDFCBK',
        body: 'Rs 250 debited from A/c XX1234',
        instrumentLast4: '1234',
        merchant: 'LOCAL CAFE DOWNTOWN',
        sources: [learned, other],
      );

      expect(match, 'ps-hdfc');
    });

    test('prefers user-learned body pattern before sender hints', () {
      final learned = _source(bodyPatterns: ['-Federal Bank']);
      final generic = _source(
        id: 'ps-sbi',
        senderHints: ['SBIINB'],
      );

      final match = matchPaymentSourceFromIngest(
        sender: 'SBIINB',
        body: 'Rs 100 debited. -Federal Bank',
        sources: [learned, generic],
      );

      expect(match, 'ps-hdfc');
    });

    test('round-trips learned hint fields through JSON', () {
      final source = _source(
        merchantHints: ['ZEPTO'],
        bodyPatterns: ['-HDFC Bank'],
      );

      final restored = PaymentSource.fromJson(source.toJson());

      expect(restored.merchantHints, ['ZEPTO']);
      expect(restored.bodyPatterns, ['-HDFC Bank']);
    });
  });
}
