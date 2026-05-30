import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/ingest/ingest_repository.dart';
import 'package:money_matters/services/ingest_parse_pipeline.dart';

void main() {
  group('IngestDrainResult', () {
    test('formatSyncMessage distinguishes synced vs parsed counts', () {
      const withParsed = IngestDrainResult(
        rawIngestsSynced: 9,
        parseJobsSynced: 0,
        transactionsSynced: 0,
        parseResult: ParsePipelineResult(
          processed: 9,
          transactionsCreated: 3,
          skipped: 6,
          failed: 0,
        ),
      );
      expect(
        withParsed.formatSyncMessage(),
        'Synced 9 item(s), parsed 3 transaction(s)',
      );

      const syncedOnly = IngestDrainResult(
        rawIngestsSynced: 9,
        parseJobsSynced: 0,
        transactionsSynced: 0,
        parseResult: ParsePipelineResult(
          processed: 9,
          transactionsCreated: 0,
          skipped: 9,
          failed: 0,
        ),
      );
      expect(
        syncedOnly.formatSyncMessage(),
        'Synced 9 item(s), 0 transactions parsed',
      );

      const upToDate = IngestDrainResult(
        rawIngestsSynced: 0,
        parseJobsSynced: 0,
        transactionsSynced: 0,
      );
      expect(upToDate.formatSyncMessage(), 'Already up to date');
    });
  });
}
