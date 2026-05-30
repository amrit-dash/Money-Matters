import 'package:uuid/uuid.dart';

import 'package:money_matters/models/raw_ingest.dart';

import '../../ingest/ingest_repository.dart';
import 'recovery_repository.dart';

/// In-memory stub until ingest layer is wired.
class MockRecoveryRepository implements RecoveryRepository {
  MockRecoveryRepository();

  DateTime? _lastSync;
  DateTime? _lastIngest;
  int _pending = 3;

  @override
  Future<IngestStatus> status() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return IngestStatus(
      lastSyncAt: _lastSync ?? DateTime.now().subtract(const Duration(hours: 2)),
      pendingCount: _pending,
      lastIngestAt:
          _lastIngest ?? DateTime.now().subtract(const Duration(minutes: 45)),
      failedParseCount: 0,
    );
  }

  @override
  Future<List<RawIngest>> submitPastedMessages(
    List<String> messageBodies,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    _lastIngest = now;
    _pending += messageBodies.length;

    return messageBodies.map((body) {
      return RawIngest(
        id: const Uuid().v4(),
        body: body,
        sender: 'manual-paste',
        receivedAt: now,
        deviceId: 'local',
        source: 'manual-paste',
        batchHint: null,
        createdAt: now,
        duplicate: false,
      );
    }).toList();
  }

  @override
  Future<void> triggerSync() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _lastSync = DateTime.now();
    _pending = 0;
  }

  @override
  IngestDrainResult? get lastSyncResult => null;
}
