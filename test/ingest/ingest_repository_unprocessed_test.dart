import 'package:cloud_firestore/cloud_firestore.dart';
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

  group('IngestRepository.processedAtIsoFromFirestore', () {
    test('returns null when ingest is unprocessed', () {
      expect(
        IngestRepository.processedAtIsoFromFirestore({'processedAt': null}),
        isNull,
      );
    });

    test('maps Firestore Timestamp to UTC ISO-8601', () {
      final when = DateTime.utc(2026, 5, 30, 12, 30);
      expect(
        IngestRepository.processedAtIsoFromFirestore({
          'processedAt': Timestamp.fromDate(when),
        }),
        when.toIso8601String(),
      );
    });

    test('maps ISO string processedAt to UTC ISO-8601', () {
      expect(
        IngestRepository.processedAtIsoFromFirestore({
          'processedAt': '2026-05-30T12:30:00Z',
        }),
        '2026-05-30T12:30:00.000Z',
      );
    });
  });
}
