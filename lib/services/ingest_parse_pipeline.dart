import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/foundation.dart' show debugPrint;

import '../core/auth/auth_service.dart';
import '../core/db/local_database.dart';
import '../models/category.dart';
import '../models/payment_source.dart';
import '../models/raw_ingest.dart';
import '../models/transaction.dart';
import '../features/dashboard/local_dashboard_repository.dart';
import '../parse/llm_parser.dart';
import '../parse/parse_service.dart';
import '../services/category_service.dart';
import '../services/payment_source_service.dart';

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
    PaymentSourceService? paymentSourceService,
    CategoryService? categoryService,
    TransactionClassifier? classifier,
    FirebaseFirestore? firestore,
  })  : _localDatabase = localDatabase,
        _authService = authService,
        _parseService = parseService ?? ParseService(),
        _paymentSourceService = paymentSourceService,
        _categoryService = categoryService ?? CategoryService(),
        _classifier = classifier ?? const NoOpTransactionClassifier(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final LocalDatabase _localDatabase;
  final AuthService _authService;
  final ParseService _parseService;
  final PaymentSourceService? _paymentSourceService;
  final CategoryService _categoryService;
  final TransactionClassifier _classifier;
  final FirebaseFirestore _firestore;

  static const _rulesVersion = 'rules-v1';
  static const _parseJobsCollection = 'parse_jobs';
  static const _transactionsCollection = 'transactions';

  Future<ParsePipelineResult> processPending({
    List<PaymentSource>? paymentSources,
    List<Category>? categories,
  }) async {
    if (!_authService.isSignedIn) {
      return const ParsePipelineResult(
        processed: 0,
        transactionsCreated: 0,
        skipped: 0,
        failed: 0,
      );
    }

    final sources = paymentSources ??
        await _paymentSourceService?.loadAll() ??
        const <PaymentSource>[];
    final cats = categories ?? await _categoryService.loadCategories();

    final rows = await _localDatabase.getUnprocessedRawIngests();
    var processed = 0;
    var transactionsCreated = 0;
    var skipped = 0;
    var failed = 0;

    for (final row in rows) {
      final ingest = _rawIngestFromRow(row);
      try {
        final outcome = await _parseService.parse(
          ingest,
          paymentSources: sources,
          categories: cats,
        );

        if (outcome.transaction != null) {
          // Stable id = raw ingest id (one SMS → one transaction, idempotent retries).
          var tx = outcome.transaction!.copyWith(id: ingest.id);
          tx = await _maybeMatchPaymentSource(tx, ingest, sources);
          tx = await _maybeClassify(tx, ingest, cats, sources);
          await _persistTransaction(tx);
          transactionsCreated++;
        } else {
          skipped++;
        }

        await _localDatabase.markRawIngestProcessed(ingest.id);
        await _markParseJobDone(ingest.id);
        processed++;
      } catch (e, st) {
        debugPrint(
          'IngestParsePipeline: failed ${ingest.id}: $e\n$st',
        );
        await _markParseJobFailed(ingest.id, e);
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

  /// Rules-first match using sender hints and SMS body before any LLM call.
  Future<Transaction> _maybeMatchPaymentSource(
    Transaction tx,
    RawIngest ingest,
    List<PaymentSource> sources,
  ) async {
    final knownIds = sources.map((s) => s.id).toSet();
    if (!LocalDashboardRepository.isUnmatched(tx, knownIds)) return tx;

    final rulesMatch = matchPaymentSourceFromIngest(
      sender: ingest.sender,
      body: ingest.body,
      sources: sources,
    );
    if (rulesMatch == null) return tx;

    return tx.copyWith(paymentSourceId: rulesMatch, unmatched: false);
  }

  /// Rules-first LLM gate for category and payment-source assignment.
  /// Any failure or missing config keeps the transaction in the in-app inbox.
  Future<Transaction> _maybeClassify(
    Transaction tx,
    RawIngest ingest,
    List<Category> categories,
    List<PaymentSource> sources,
  ) async {
    final knownIds = sources.map((s) => s.id).toSet();
    final needsCategory = tx.needsClassification || tx.ambiguous;
    final needsSource =
        LocalDashboardRepository.isUnmatched(tx, knownIds) && sources.isNotEmpty;
    if (!needsCategory && !needsSource) return tx;

    final result = await _classifier.classify(
      transaction: tx,
      smsBody: ingest.body,
      categoryIds: categories.map((c) => c.id).toList(),
      paymentSources: sources,
    );
    if (result == null || result.needsConfig) return tx;

    var updated = tx;

    if (needsSource &&
        result.paymentSourceId != null &&
        knownIds.contains(result.paymentSourceId) &&
        (result.paymentSourceConfidence ?? 0) >=
            ClassificationResult.paymentSourceConfidenceThreshold) {
      updated = updated.copyWith(
        paymentSourceId: result.paymentSourceId,
        unmatched: false,
      );
    }

    if (needsCategory) {
      final validCategory = result.categoryId != null &&
          categories.any((c) => c.id == result.categoryId);
      final categoryId = validCategory ? result.categoryId : updated.categoryId;
      final resolved = categoryId != null && !result.needsUserInput;

      updated = updated.copyWith(
        categoryId: categoryId,
        merchantNormalized: result.merchantNormalized ?? updated.merchantNormalized,
        needsClassification:
            resolved ? false : updated.needsClassification,
        ambiguous: resolved ? false : updated.ambiguous,
        classifiedBy: resolved ? ClassifiedBy.llm : updated.classifiedBy,
      );
    } else if (result.merchantNormalized != null) {
      updated = updated.copyWith(merchantNormalized: result.merchantNormalized);
    }

    return updated;
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
      'excluded': tx.excluded ? 1 : 0,
      'type': tx.type.name,
      'needs_classification': tx.needsClassification ? 1 : 0,
      'merchant_normalized': tx.merchantNormalized,
      'user_notes': tx.userNotes,
      'shopping_items':
          tx.shoppingItems.isEmpty ? null : jsonEncode(tx.shoppingItems),
      'classified_by': tx.classifiedBy?.name,
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

  Future<void> _markParseJobFailed(String rawIngestId, Object error) async {
    final uid = _authService.requireUid();
    final errorMsg = error.toString();
    final now = DateTime.now().toUtc().toIso8601String();

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
        'status': 'failed',
        'error': errorMsg,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _localDatabase.upsertParseJob({
        'id': doc.id,
        'raw_ingest_id': rawIngestId,
        'status': 'failed',
        'rules_version': _rulesVersion,
        'error': errorMsg,
        'updated_at': now,
        'synced_at': now,
      });
    }
  }
}
