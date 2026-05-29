import 'package:money_matters/models/raw_ingest.dart';

/// Ingest queue status for recovery screen placeholders.
class IngestStatus {
  const IngestStatus({
    this.lastSyncAt,
    this.pendingCount = 0,
    this.lastIngestAt,
    this.failedParseCount = 0,
  });

  final DateTime? lastSyncAt;
  final int pendingCount;
  final DateTime? lastIngestAt;
  final int failedParseCount;
}

/// Manual recovery: multi-paste ingest + queue status.
abstract class RecoveryRepository {
  Future<IngestStatus> status();
  Future<List<RawIngest>> submitPastedMessages(List<String> messageBodies);
  Future<void> triggerSync();
}

/// Splits pasted text into individual SMS blocks (blank-line separated).
List<String> splitPastedMessages(String text) {
  return text
      .split(RegExp(r'\n\s*\n'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty)
      .toList();
}
