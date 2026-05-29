import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:uuid/uuid.dart';

import '../core/auth/auth_service.dart';
import '../core/db/local_database.dart';
import '../models/category.dart';
import '../models/payment_source.dart';
import '../models/raw_ingest.dart';
import '../models/transaction.dart';
import '../parse/parse_service.dart';

/// Result of processing local unprocessed ingests through the rules parser.
class ParsePipelineResult {
  const ParsePipelineResult({
    required this.processed,
    required this.transactionsCreated,
    required this.skipped,
    required this.failed,
  });

  final int processed;
  final int transactionsCreated;
  final int skipped;
  final int failed;
}

/// Drains local SQLite queue: parse → persist → mark processed (Coordinator-owned).
class IngestParsePipeline {
  IngestParsePipeline({
    required LocalDatabase localDatabase,
    required AuthService authService,
    ParseService? parseService,
    FirebaseFirestore? firestore,
  })  : _localDatabase = localDatabase,
        _authService = authService,
        _parseService = parseService ?? ParseService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final LocalDatabase _localDatabase;
  final AuthService _authService;
  final ParseService _parseService;
  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  static const _rulesVersion = 'mvp-1';
  static const _parseJobsCollection = 'parse_jobs';
  static const _transactionsCollection = 'transactions';

  Future<ParsePipelineResult> processPending({
    List<PaymentSource> paymentSources = const [],
    List<Category> categories = const [],
  }) async {
    if (!_authService.isSignedIn) {
      return const ParsePipelineResult(
        processed: 0,
        transactionsCreated: 0,
        skipped: 0,
        failed: 0,
      );
    }

    final rows = await _localDatabase.getUnprocessedRawIngests();
    var processed = 0;
    var transactionsCreated = 0;
    var skipped = 0;
    var failed = 0;

    for (final row in rows) {
      try {
        final ingest = _rawIngestFromRow(row);
        final outcome = await _parseService.parse(
          ingest,
          paymentSources: paymentSources,
          categories: categories,
        );

        if (outcome.transaction != null) {
          final tx = outcome.transaction!.copyWith(
            id: outcome.transaction!.id ?? _uuid.v4(),
          );
          await _persistTransaction(tx);
          transactionsCreated++;
        } else {
          skipped++;
        }

        await _localDatabase.markRawIngestProcessed(ingest.id);
        await _markParseJobDone(ingest.id);
        processed++;
      } catch (_) {
        failed++;
      }
    }

    return ParsePipelineResult(
      processed: processed,
      transactionsCreated: transactionsCreated,
      skipped: skipped,
      failed: failed,
    );
  }

  RawIngest _rawIngestFromRow(Map<String, dynamic> row) {
    return RawIngest(
      id: row['idempotency_key'] as String,
      body: row['body'] as String,
      sender: row['sender'] as String,
      receivedAt: DateTime.parse(row['received_at'] as String),
      deviceId: row['device_id'] as String? ?? '',
      source: row['source'] as String,
      batchHint: row['batch_hint'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.parse(row['received_at'] as String),
      duplicate: (row['duplicate'] as int? ?? 0) == 1,
    );
  }

  Future<void> _persistTransaction(Transaction tx) async {
    final syncedAt = DateTime.now().toUtc().toIso8601String();
    await _localDatabase.upsertTransaction({
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
      'synced_at': syncedAt,
    });

    final uid = _authService.requireUid();
    await _firestore
        .collection('users')
        .doc(uid)
        .collection(_transactionsCollection)
        .doc(tx.id)
        .set({
      ...tx.toJson(),
      'timestamp': Timestamp.fromDate(tx.timestamp),
      'processedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _markParseJobDone(String rawIngestId) async {
    final uid = _authService.requireUid();
    final jobs = await _firestore
        .collection('users')
        .doc(uid)
        .collection(_parseJobsCollection)
        .where('rawIngestId', isEqualTo: rawIngestId)
        .where('status', isEqualTo: 'pending')
        .limit(5)
        .get();

    for (final doc in jobs.docs) {
      await doc.reference.update({
        'status': 'done',
        'rulesVersion': _rulesVersion,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _localDatabase.upsertParseJob({
        'id': doc.id,
        'raw_ingest_id': rawIngestId,
        'status': 'done',
        'rules_version': _rulesVersion,
        'error': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'synced_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('raw_ingests')
        .doc(rawIngestId)
        .update({'processedAt': FieldValue.serverTimestamp()});
  }
}
