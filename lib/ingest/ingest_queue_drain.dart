import 'dart:async';

import '../core/auth/auth_service.dart';
import '../services/ingest_parse_pipeline.dart';
import 'ingest_repository.dart';

/// Orchestrates Firestore queue drain on app launch and foreground refresh.
class IngestQueueDrain {
  IngestQueueDrain({
    required IngestRepository repository,
    required AuthService authService,
    IngestParsePipeline? parsePipeline,
  })  : _repository = repository,
        _authService = authService,
        _parsePipeline = parsePipeline;

  final IngestRepository _repository;
  final AuthService _authService;
  final IngestParsePipeline? _parsePipeline;

  final StreamController<IngestDrainResult> _drainEvents =
      StreamController<IngestDrainResult>.broadcast();

  Future<IngestDrainResult?>? _inFlight;
  IngestDrainResult? _lastResult;
  DateTime? _lastSyncAt;

  /// Emits after each successful drain + parse cycle.
  Stream<IngestDrainResult> get onDrained => _drainEvents.stream;

  IngestDrainResult? get lastResult => _lastResult;
  DateTime? get lastSyncAt => _lastSyncAt;

  /// Drains pending Firestore ingests into SQLite when user is signed in.
  ///
  /// Safe to call repeatedly; concurrent calls await the same in-flight cycle.
  Future<IngestDrainResult?> drainIfAuthenticated() async {
    if (!_authService.isSignedIn) {
      return null;
    }

    if (_inFlight != null) {
      return _inFlight;
    }

    _inFlight = _runDrainCycle();
    try {
      return await _inFlight;
    } finally {
      _inFlight = null;
    }
  }

  Future<IngestDrainResult?> _runDrainCycle() async {
    final drainResult = await _repository.drainPending();
    ParsePipelineResult? parseResult;
    if (_parsePipeline != null) {
      parseResult = await _parsePipeline.processPending();
    }

    final result = IngestDrainResult(
      rawIngestsSynced: drainResult.rawIngestsSynced,
      parseJobsSynced: drainResult.parseJobsSynced,
      transactionsSynced: drainResult.transactionsSynced,
      parseResult: parseResult,
    );
    _lastResult = result;
    _lastSyncAt = DateTime.now();

    if (result.totalSynced > 0 || result.transactionsParsed > 0) {
      _drainEvents.add(result);
    }
    return result;
  }

  /// Returns combined local pending counts for status UI.
  Future<Map<String, int>> localPendingCounts() => _repository.pendingCounts();

  void dispose() {
    _drainEvents.close();
  }
}
