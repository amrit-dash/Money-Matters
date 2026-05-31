import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/ingest/ingest_repository.dart';

void main() {
  group('IngestRepository.isUnprocessedRawIngest', () {
    test('missing processedAt is unprocessed (legacy ingestSms docs)', () {
      expect(
        IngestRepository.isUnprocessedRawIngest({'body': 'test'}),
        isTrue,
      );
    });

    test('explicit null processedAt is unprocessed', () {
      expect(
        IngestRepository.isUnprocessedRawIngest({'processedAt': null}),
        isTrue,
      );
    });

    test('timestamp processedAt is processed', () {
      expect(
        IngestRepository.isUnprocessedRawIngest({
          'processedAt': '2026-05-30T00:00:00Z',
        }),
        isFalse,
      );
    });
  });
}
