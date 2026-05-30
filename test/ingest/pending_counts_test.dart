import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/features/recovery/recovery_repository.dart';

void main() {
  group('IngestStatus pending metrics', () {
    test('awaitingParseCount does not double-count parse jobs', () {
      const status = IngestStatus(
        pendingMessageCount: 3,
        pendingParseJobCount: 3,
      );
      expect(status.awaitingParseCount, 3);
      expect(status.totalPending, 3);
      expect(status.pendingParseJobsCount, 3);
    });

    test('parse jobs out of sync when counts diverge', () {
      const inSync = IngestStatus(
        pendingMessageCount: 2,
        pendingParseJobCount: 2,
      );
      const outOfSync = IngestStatus(
        pendingMessageCount: 0,
        pendingParseJobCount: 2,
      );
      expect(
        inSync.pendingParseJobsCount != inSync.awaitingParseCount,
        isFalse,
      );
      expect(
        outOfSync.pendingParseJobsCount != outOfSync.awaitingParseCount,
        isTrue,
      );
    });
  });
}
