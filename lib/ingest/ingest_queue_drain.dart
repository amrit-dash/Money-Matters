import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

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
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw StateError(
          'Firestore permission denied — sign out and back in, or check Firebase rules',
        );
      }
      rethrow;
    } finally {
      _inFlight = null;
    }
  }

  static const _maxDrainCycles = 10;

  Future<IngestDrainResult?> _runDrainCycle() async {
    var rawIngestsSynced = 0;
    var parseJobsSynced = 0;
    var transactionsSynced = 0;
    ParsePipelineResult? parseResult;

    for (var cycle = 0; cycle < _maxDrainCycles; cycle++) {
      final drainResult = await _repository.drainPending();
      rawIngestsSynced += drainResult.rawIngestsSynced;
      parseJobsSynced += drainResult.parseJobsSynced;
      transactionsSynced += drainResult.transactionsSynced;

      if (_parsePipeline != null) {
        parseResult = _mergeParseResults(
          parseResult,
          await _parsePipeline.processPending(),
        );
      }

      final pending = await _repository.pendingCounts();
      final awaitingParse = pending['awaitingParse'] ?? 0;
      if (drainResult.totalSynced == 0 && awaitingParse == 0) {
        break;
      }
    }

    final result = IngestDrainResult(
      rawIngestsSynced: rawIngestsSynced,
      parseJobsSynced: parseJobsSynced,
      transactionsSynced: transactionsSynced,
      parseResult: parseResult,
    );
    _lastResult = result;
    _lastSyncAt = DateTime.now();

    if (result.totalSynced > 0 ||
        (parseResult?.processed ?? 0) > 0 ||
        (parseResult?.failed ?? 0) > 0) {
      _drainEvents.add(result);
    }
    return result;
  }

  ParsePipelineResult _mergeParseResults(
    ParsePipelineResult? previous,
    ParsePipelineResult current,
  ) {
    if (previous == null) return current;
    return ParsePipelineResult(
      processed: previous.processed + current.processed,
      transactionsCreated:
          previous.transactionsCreated + current.transactionsCreated,
      skipped: previous.skipped + current.skipped,
      failed: previous.failed + current.failed,
    );
  }

  /// Returns combined local pending counts for status UI.
  Future<Map<String, int>> localPendingCounts() => _repository.pendingCounts();

  void dispose() {
    _drainEvents.close();
  }
}
