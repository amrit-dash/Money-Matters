import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/auth/auth_service.dart';
import '../core/db/local_database.dart';
import '../models/parse_job.dart';
import '../models/raw_ingest.dart';
import '../models/transaction.dart' as ledger;
import '../services/ingest_parse_pipeline.dart';

/// Result of a Firestore → SQLite drain cycle.
class IngestDrainResult {
  const IngestDrainResult({
    required this.rawIngestsSynced,
    required this.parseJobsSynced,
    required this.transactionsSynced,
    this.parseResult,
  });

  final int rawIngestsSynced;
  final int parseJobsSynced;
  final int transactionsSynced;
  final ParsePipelineResult? parseResult;

  int get totalSynced =>
      rawIngestsSynced + parseJobsSynced + transactionsSynced;

  int get transactionsParsed => parseResult?.transactionsCreated ?? 0;

  /// User-facing summary after drain + local parse.
  String formatSyncMessage() {
    final parsed = transactionsParsed;
    final processed = parseResult?.processed ?? 0;
    final failed = parseResult?.failed ?? 0;
    if (totalSynced == 0 && processed == 0 && failed == 0) {
      return 'Nothing new to sync — cloud queue may already be empty';
    }
    final parts = <String>[];
    if (rawIngestsSynced > 0) {
      parts.add('Downloaded $rawIngestsSynced SMS from cloud');
    } else if (parseJobsSynced > 0 || transactionsSynced > 0) {
      parts.add('Updated local mirror');
    }
    if (processed > 0) {
      parts.add('processed $processed on device');
    }
    if (parsed > 0) {
      parts.add('$parsed transaction(s) created');
    } else if (processed > 0) {
      parts.add('0 transactions matched');
    }
    if (failed > 0) {
      parts.add('$failed parse(s) failed');
    }
    if (parts.isEmpty) {
      return 'Already up to date';
    }
    return parts.join(', ');
  }

  @override
  String toString() =>
      'IngestDrainResult(raw=$rawIngestsSynced, jobs=$parseJobsSynced, '
      'tx=$transactionsSynced, parsed=$transactionsParsed)';
}

/// Drains pending [raw_ingests], [parse_jobs], and [transactions] from Firestore
/// into the local SQLite mirror.
class IngestRepository {
  IngestRepository({
    required AuthService authService,
    required LocalDatabase localDatabase,
    FirebaseFirestore? firestore,
  })  : _authService = authService,
        _localDatabase = localDatabase,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthService _authService;
  final LocalDatabase _localDatabase;
  final FirebaseFirestore _firestore;

  static const _rawIngestsCollection = 'raw_ingests';
  static const _parseJobsCollection = 'parse_jobs';
  static const _transactionsCollection = 'transactions';
  static const _pendingStatus = 'pending';
  static const _drainBatchSize = 100;

  CollectionReference<Map<String, dynamic>> _userCollection(String name) {
    final uid = _authService.requireUid();
    return _firestore.collection('users').doc(uid).collection(name);
  }

  /// Pulls unprocessed ingests, pending parse jobs, and recent transactions.
  Future<IngestDrainResult> drainPending() async {
    final syncedAt = DateTime.now().toUtc().toIso8601String();
    var rawCount = 0;
    var jobCount = 0;
    var txCount = 0;

    jobCount = await _drainPendingParseJobs(syncedAt);
    rawCount = await _drainUnprocessedRawIngests(syncedAt);
    txCount = await _drainRecentTransactions(syncedAt);

    return IngestDrainResult(
      rawIngestsSynced: rawCount,
      parseJobsSynced: jobCount,
      transactionsSynced: txCount,
    );
  }

  /// True when [data] has no [processedAt] or it is explicitly null.
  static bool isUnprocessedRawIngest(Map<String, dynamic> data) {
    if (!data.containsKey('processedAt')) return true;
    final value = data['processedAt'];
    return value == null;
  }

  Future<int> _drainUnprocessedRawIngests(String syncedAt) async {
    var count = 0;

    // Matches docs with processedAt: null (new ingests after CF fix).
    final nullProcessed = await _userCollection(_rawIngestsCollection)
        .where('processedAt', isNull: true)
        .orderBy('createdAt')
        .limit(_drainBatchSize)
        .get();

    for (final doc in nullProcessed.docs) {
      count += await _upsertRawIngestDoc(doc.id, doc.data(), syncedAt) ? 1 : 0;
    }

    // Legacy ingests omit processedAt entirely; isNull does not match missing fields.
    if (count < _drainBatchSize) {
      final legacy = await _userCollection(_rawIngestsCollection)
          .orderBy('createdAt', descending: true)
          .limit(_drainBatchSize)
          .get();

      for (final doc in legacy.docs) {
        if (!isUnprocessedRawIngest(doc.data())) continue;
        if (nullProcessed.docs.any((d) => d.id == doc.id)) continue;
        count += await _upsertRawIngestDoc(doc.id, doc.data(), syncedAt) ? 1 : 0;
        if (count >= _drainBatchSize) break;
      }
    }

    return count;
  }

  Future<bool> _upsertRawIngestDoc(
    String id,
    Map<String, dynamic> data,
    String syncedAt,
  ) async {
    if (!isUnprocessedRawIngest(data)) return false;

    final ingest = _rawIngestFromFirestore(id, data);
    final row = _rawIngestToSqlite(ingest, syncedAt);
    final existing = await _localDatabase.getRawIngest(ingest.id);
    if (existing?['processed_at'] != null) {
      row['processed_at'] = existing!['processed_at'];
    }
    await _localDatabase.upsertRawIngest(row);
    return true;
  }

  Future<int> _drainPendingParseJobs(String syncedAt) async {
    final snapshot = await _userCollection(_parseJobsCollection)
        .where('status', isEqualTo: _pendingStatus)
        .orderBy('updatedAt')
        .limit(_drainBatchSize)
        .get();

    var count = 0;
    for (final doc in snapshot.docs) {
      final job = _parseJobFromFirestore(doc.id, doc.data());
      await _drainRawIngestForJob(job.rawIngestId, syncedAt);
      final row = _parseJobToSqlite(job, syncedAt);
      final existing = await _localDatabase.getParseJob(job.id);
      final existingStatus = existing?['status'] as String?;
      if (existingStatus != null && existingStatus != _pendingStatus) {
        row['status'] = existingStatus;
        row['error'] = existing!['error'];
        row['rules_version'] = existing['rules_version'];
      }
      await _localDatabase.upsertParseJob(row);
      count++;
    }
    return count;
  }

  /// Ensures the SMS body for a pending parse job exists locally (orphan-job fix).
  Future<void> _drainRawIngestForJob(String rawIngestId, String syncedAt) async {
    if (rawIngestId.isEmpty) return;

    final local = await _localDatabase.getRawIngest(rawIngestId);
    if (local != null && local['processed_at'] == null) return;

    final doc =
        await _userCollection(_rawIngestsCollection).doc(rawIngestId).get();
    if (!doc.exists) return;
    await _upsertRawIngestDoc(doc.id, doc.data()!, syncedAt);
  }

  /// Mirrors transactions updated since last local sync watermark.
  ///
  /// Uses a rolling 30-day window; sync policy may be refined later.
  Future<int> _drainRecentTransactions(String syncedAt) async {
    final since = DateTime.now().toUtc().subtract(const Duration(days: 30));
    final snapshot = await _userCollection(_transactionsCollection)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('timestamp')
        .limit(_drainBatchSize)
        .get();

    var count = 0;
    for (final doc in snapshot.docs) {
      final tx = _transactionFromFirestore(doc.id, doc.data());
      await _localDatabase.upsertTransaction(_transactionToSqlite(tx, syncedAt));
      count++;
    }
    return count;
  }

  /// Returns local pending counts for ingest status UI.
  ///
  /// [awaitingParse] is the canonical pending metric: unprocessed SMS on device.
  /// Each SMS also has a parse job, so raw + jobs must not be summed (double count).
  Future<Map<String, int>> pendingCounts() async {
    final rawIngests = await _localDatabase.countPendingRawIngests();
    final parseJobs = await _localDatabase.countPendingParseJobs();
    return {
      'rawIngests': rawIngests,
      'parseJobs': parseJobs,
      'awaitingParse': rawIngests,
    };
  }

  /// Pending queue depth in Firestore (not yet mirrored or parsed on device).
  Future<Map<String, int>> cloudPendingCounts() async {
    final jobs = await _userCollection(_parseJobsCollection)
        .where('status', isEqualTo: _pendingStatus)
        .count()
        .get();
    final pendingJobs = jobs.count ?? 0;
    return {
      'parseJobs': pendingJobs,
      'awaitingParse': pendingJobs,
    };
  }

  /// Most recent SMS received in cloud (for Recovery "Last ingest" when local is empty).
  Future<DateTime?> cloudLatestIngestTime() async {
    final snapshot = await _userCollection(_rawIngestsCollection)
        .orderBy('receivedAt', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return _toDateTime(snapshot.docs.first.data()['receivedAt']);
  }

  RawIngest _rawIngestFromFirestore(String id, Map<String, dynamic> data) {
    return RawIngest(
      id: id,
      body: data['body'] as String? ?? '',
      sender: data['sender'] as String? ?? '',
      receivedAt: _toDateTime(data['receivedAt']),
      deviceId: data['deviceId'] as String? ?? '',
      source: data['source'] as String? ?? 'unknown',
      batchHint: data['batchHint'] as String?,
      createdAt: _toDateTime(data['createdAt']),
      duplicate: data['duplicate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _rawIngestToSqlite(RawIngest ingest, String syncedAt) {
    return {
      'idempotency_key': ingest.id,
      'body': ingest.body,
      'sender': ingest.sender,
      'received_at': ingest.receivedAt.toUtc().toIso8601String(),
      'device_id': ingest.deviceId,
      'source': ingest.source,
      'batch_hint': ingest.batchHint,
      'created_at': ingest.createdAt.toUtc().toIso8601String(),
      'duplicate': ingest.duplicate ? 1 : 0,
      'processed_at': null,
      'synced_at': syncedAt,
    };
  }

  ParseJob _parseJobFromFirestore(String id, Map<String, dynamic> data) {
    return ParseJob(
      id: id,
      rawIngestId: data['rawIngestId'] as String? ?? '',
      status: ParseJobStatus.fromString(
        data['status'] as String? ?? _pendingStatus,
      ),
      rulesVersion: data['rulesVersion'] as String? ?? '',
      error: data['error'] as String?,
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> _parseJobToSqlite(ParseJob job, String syncedAt) {
    return {
      'id': job.id,
      'raw_ingest_id': job.rawIngestId,
      'status': job.status.name,
      'rules_version': job.rulesVersion,
      'error': job.error,
      'updated_at': job.updatedAt.toUtc().toIso8601String(),
      'synced_at': syncedAt,
    };
  }

  ledger.Transaction _transactionFromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return ledger.Transaction(
      id: id,
      rawIngestId: data['rawIngestId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency'] as String? ?? 'INR',
      merchant: data['merchant'] as String?,
      timestamp: _toDateTime(data['timestamp']),
      categoryId: data['categoryId'] as String?,
      paymentSourceId: data['paymentSourceId'] as String?,
      unmatched: data['unmatched'] as bool? ?? false,
      ambiguous: data['ambiguous'] as bool? ?? false,
      type: ledger.TransactionType.fromString(
        data['type'] as String? ?? 'debit',
      ),
      needsClassification: data['needsClassification'] as bool? ?? false,
      merchantNormalized: data['merchantNormalized'] as String?,
      userNotes: data['userNotes'] as String?,
      shoppingItems: (data['shoppingItems'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      classifiedBy: ledger.ClassifiedBy.fromString(
        data['classifiedBy'] as String?,
      ),
    );
  }

  Map<String, dynamic> _transactionToSqlite(
    ledger.Transaction tx,
    String syncedAt,
  ) {
    return {
      'id': tx.id,
      'raw_ingest_id': tx.rawIngestId,
      'amount': tx.amount,
      'currency': tx.currency,
      'merchant': tx.merchant,
      'timestamp': tx.timestamp.toUtc().toIso8601String(),
      'category_id': tx.categoryId,
      'payment_source_id': tx.paymentSourceId,
      'unmatched': tx.unmatched ? 1 : 0,
      'ambiguous': tx.ambiguous ? 1 : 0,
      'type': tx.type.name,
      'needs_classification': tx.needsClassification ? 1 : 0,
      'merchant_normalized': tx.merchantNormalized,
      'user_notes': tx.userNotes,
      'shopping_items':
          tx.shoppingItems.isEmpty ? null : jsonEncode(tx.shoppingItems),
      'classified_by': tx.classifiedBy?.name,
      'synced_at': syncedAt,
    };
  }

  DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
    }
    return DateTime.now().toUtc();
  }
}
