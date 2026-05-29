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

  bool _isDraining = false;
  IngestDrainResult? _lastResult;
  DateTime? _lastSyncAt;

  /// Emits after each successful drain cycle.
  Stream<IngestDrainResult> get onDrained => _drainEvents.stream;

  IngestDrainResult? get lastResult => _lastResult;
  DateTime? get lastSyncAt => _lastSyncAt;

  /// Drains pending Firestore ingests into SQLite when user is signed in.
  ///
  /// Safe to call repeatedly; concurrent calls coalesce into one in-flight drain.
  Future<IngestDrainResult?> drainIfAuthenticated() async {
    if (!_authService.isSignedIn) {
      return null;
    }

    if (_isDraining) {
      return _lastResult;
    }

    _isDraining = true;
    try {
      final result = await _repository.drainPending();
      _lastResult = result;
      _lastSyncAt = DateTime.now();
      if (_parsePipeline != null) {
        await _parsePipeline.processPending();
      }
      if (result.totalSynced > 0) {
        _drainEvents.add(result);
      }
      return result;
    } finally {
      _isDraining = false;
    }
  }

  /// Returns combined local pending counts for status UI.
  Future<Map<String, int>> localPendingCounts() => _repository.pendingCounts();

  void dispose() {
    _drainEvents.close();
  }
}
