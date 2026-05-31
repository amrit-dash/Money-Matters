import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/ingest/ingest_repository.dart';
import 'package:money_matters/services/ingest_parse_pipeline.dart';

void main() {
  group('IngestDrainResult', () {
    test('formatSyncMessage distinguishes download vs parse', () {
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
        'Downloaded 9 SMS from cloud, processed 9 on device, 3 transaction(s) created',
      );

      const withFailures = IngestDrainResult(
        rawIngestsSynced: 2,
        parseJobsSynced: 0,
        transactionsSynced: 0,
        parseResult: ParsePipelineResult(
          processed: 1,
          transactionsCreated: 1,
          skipped: 0,
          failed: 1,
        ),
      );
      expect(
        withFailures.formatSyncMessage(),
        'Downloaded 2 SMS from cloud, processed 1 on device, 1 transaction(s) created, 1 parse(s) failed',
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
        'Downloaded 9 SMS from cloud, processed 9 on device, 0 transactions matched',
      );

      const upToDate = IngestDrainResult(
        rawIngestsSynced: 0,
        parseJobsSynced: 0,
        transactionsSynced: 0,
      );
      expect(
        upToDate.formatSyncMessage(),
        'Nothing new to sync — cloud queue may already be empty',
      );

      const withLlm = IngestDrainResult(
        rawIngestsSynced: 0,
        parseJobsSynced: 0,
        transactionsSynced: 0,
        parseResult: ParsePipelineResult(
          processed: 0,
          transactionsCreated: 0,
          skipped: 0,
          failed: 0,
          rematched: 2,
          reclassified: 3,
        ),
      );
      expect(
        withLlm.formatSyncMessage(),
        '2 account(s) matched, 3 auto-classified',
      );

      const needsConfig = IngestDrainResult(
        rawIngestsSynced: 0,
        parseJobsSynced: 0,
        transactionsSynced: 0,
        parseResult: ParsePipelineResult(
          processed: 0,
          transactionsCreated: 0,
          skipped: 0,
          failed: 0,
          classifyNeedsConfig: true,
        ),
      );
      expect(
        needsConfig.formatSyncMessage(),
        'LLM needs GEMINI_API_KEY secret',
      );
    });
  });
}
