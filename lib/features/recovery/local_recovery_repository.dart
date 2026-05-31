import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:money_matters/models/raw_ingest.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/device_credentials_store.dart';
import '../../core/db/local_database.dart';
import '../../ingest/ingest_queue_drain.dart';
import '../../ingest/ingest_repository.dart';
import 'recovery_repository.dart';

/// Recovery backed by real ingest queue drain and manual POST for pasted SMS.
class LocalRecoveryRepository implements RecoveryRepository {
  LocalRecoveryRepository({
    required LocalDatabase localDatabase,
    required IngestRepository ingestRepository,
    required IngestQueueDrain queueDrain,
    required AuthService authService,
    DeviceCredentialsStore? credentialsStore,
    http.Client? httpClient,
    this.ingestUrl = 'https://ingestsms-ajirc5tjmq-el.a.run.app',
  })  : _db = localDatabase,
        _ingestRepository = ingestRepository,
        _queueDrain = queueDrain,
        _authService = authService,
        _credentialsStore = credentialsStore ?? DeviceCredentialsStore(),
        _http = httpClient ?? http.Client();

  final LocalDatabase _db;
  final IngestRepository _ingestRepository;
  final IngestQueueDrain _queueDrain;
  final AuthService _authService;
  final DeviceCredentialsStore _credentialsStore;
  final http.Client _http;
  final String ingestUrl;

  DateTime? _lastSyncAt;

  @override
  IngestDrainResult? get lastSyncResult => _queueDrain.lastResult;

  @override
  Future<IngestStatus> status() async {
    final counts = await _ingestRepository.pendingCounts();
    final cloudCounts = await _ingestRepository.cloudPendingCounts();
    final pendingMessages = counts['awaitingParse'] ?? counts['rawIngests'] ?? 0;
    final pendingJobs = counts['parseJobs'] ?? 0;
    final cloudPending =
        cloudCounts['awaitingParse'] ?? cloudCounts['parseJobs'] ?? 0;
    final cloudJobs = cloudCounts['parseJobs'] ?? cloudPending;
    final lastLocalIngest = await _db.getLatestRawIngestTime();
    final lastCloudIngest = await _ingestRepository.cloudLatestIngestTime();
    final lastIngest = _latestTime(lastLocalIngest, lastCloudIngest);
    return IngestStatus(
      lastSyncAt: _lastSyncAt ?? _queueDrain.lastSyncAt,
      pendingCount: pendingMessages,
      lastIngestAt: lastIngest,
      failedParseCount: _queueDrain.lastResult?.parseResult?.failed ?? 0,
      syncedMessageCount: await _db.countRawIngests(),
      pendingMessageCount: pendingMessages,
      pendingParseJobCount: pendingJobs,
      cloudPendingMessageCount: cloudPending,
      cloudPendingParseJobCount: cloudJobs,
      parsedTransactionCount: await _db.countTransactions(),
    );
  }

  DateTime? _latestTime(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  @override
  Future<List<RawIngest>> submitPastedMessages(
    List<String> messageBodies,
  ) async {
    final uid = _authService.requireUid();
    final creds = await _credentialsStore.load(uid);
    if (creds == null) {
      throw StateError('Device credentials not registered');
    }

    final ingests = <RawIngest>[];
    for (final body in messageBodies) {
      final receivedAt = DateTime.now().toIso8601String();
      final payload = jsonEncode({
        'body': body,
        'sender': 'manual-paste',
        'receivedAt': receivedAt,
        'deviceId': creds.deviceId,
        'source': 'manual-paste',
        'batchHint': null,
      });

      final response = await _http.post(
        Uri.parse(ingestUrl),
        headers: {
          'Authorization': 'Bearer ${creds.token}',
          'Content-Type': 'application/json',
        },
        body: payload,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Ingest failed: HTTP ${response.statusCode}');
      }

      ingests.add(RawIngest(
        id: 'paste-${DateTime.now().microsecondsSinceEpoch}',
        body: body,
        sender: 'manual-paste',
        receivedAt: DateTime.parse(receivedAt),
        deviceId: creds.deviceId,
        source: 'manual-paste',
        batchHint: null,
        createdAt: DateTime.now(),
        duplicate: response.body.contains('"duplicate":true'),
      ));
    }

    await _queueDrain.drainIfAuthenticated();
    return ingests;
  }

  @override
  Future<void> triggerSync() async {
    final result = await _queueDrain.drainIfAuthenticated();
    if (result == null) {
      throw StateError('Sign in required to sync and parse');
    }
    _lastSyncAt = DateTime.now();
  }
}
