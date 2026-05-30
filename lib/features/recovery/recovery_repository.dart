import 'package:money_matters/models/raw_ingest.dart';

import '../../ingest/ingest_repository.dart';

/// Ingest queue status for recovery screen.
class IngestStatus {
  const IngestStatus({
    this.lastSyncAt,
    this.pendingCount = 0,
    this.lastIngestAt,
    this.failedParseCount = 0,
    this.syncedMessageCount = 0,
    this.pendingMessageCount = 0,
    this.pendingParseJobCount = 0,
    this.parsedTransactionCount = 0,
  });

  final DateTime? lastSyncAt;
  final int pendingCount;
  final DateTime? lastIngestAt;
  final int failedParseCount;

  /// SMS stored locally after cloud sync.
  final int syncedMessageCount;

  /// Raw ingests waiting to be parsed on this device.
  final int pendingMessageCount;

  /// Parse jobs still pending in the local Firestore mirror.
  final int pendingParseJobCount;

  /// Transactions created from parsed SMS.
  final int parsedTransactionCount;

  /// Canonical pending metric — one SMS, not raw + job double-counted.
  int get awaitingParseCount => pendingMessageCount;

  int get pendingParseJobsCount => pendingParseJobCount;

  /// @deprecated Prefer [awaitingParseCount].
  int get totalPending => pendingMessageCount;
}

/// Manual recovery: multi-paste ingest + queue status.
abstract class RecoveryRepository {
  Future<IngestStatus> status();
  Future<List<RawIngest>> submitPastedMessages(List<String> messageBodies);
  Future<void> triggerSync();
  IngestDrainResult? get lastSyncResult;
}

/// Splits pasted text into individual SMS blocks (blank-line separated).
List<String> splitPastedMessages(String text) {
  return text
      .split(RegExp(r'\n\s*\n'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty)
      .toList();
}
