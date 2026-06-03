import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/foundation.dart' show debugPrint;

import '../core/auth/auth_service.dart';
import '../core/db/local_database.dart';
import '../models/category.dart';
import '../models/category_taxonomy.dart';
import '../models/payment_source.dart';
import '../models/raw_ingest.dart';
import '../models/transaction.dart';
import '../features/dashboard/local_dashboard_repository.dart';
import '../parse/llm_parser.dart';
import '../parse/parse_service.dart';
import '../parse/rules_parser.dart';
import '../services/category_service.dart';
import '../services/classification_applier.dart';
import '../services/payment_source_service.dart';

/// Result of processing local unprocessed ingests through the rules parser.
class ParsePipelineResult {
  const ParsePipelineResult({
    required this.processed,
    required this.transactionsCreated,
    required this.skipped,
    required this.failed,
    this.rematched = 0,
    this.reclassified = 0,
    this.classifyNeedsConfig = false,
    this.classifyError,
  });

  final int processed;
  final int transactionsCreated;
  final int skipped;
  final int failed;

  /// Existing unmatched rows linked to a saved bank/card on this sync.
  final int rematched;

  /// Backlog rows auto-categorized or source-linked via LLM on this sync.
  final int reclassified;

  /// True when the backend reported missing GEMINI_API_KEY.
  final bool classifyNeedsConfig;

  /// Last callable/network error from LLM classify (if any).
  final String? classifyError;

  ParsePipelineResult merge(ParsePipelineResult other) {
    return ParsePipelineResult(
      processed: processed + other.processed,
      transactionsCreated: transactionsCreated + other.transactionsCreated,
      skipped: skipped + other.skipped,
      failed: failed + other.failed,
      rematched: rematched + other.rematched,
      reclassified: reclassified + other.reclassified,
      classifyNeedsConfig: classifyNeedsConfig || other.classifyNeedsConfig,
      classifyError: other.classifyError ?? classifyError,
    );
  }
}

class _ClassifyOutcome {
  const _ClassifyOutcome({
    required this.transaction,
    this.needsConfig = false,
    this.error,
    this.applied = false,
  });

  final Transaction transaction;
  final bool needsConfig;
  final String? error;
  final bool applied;
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

  /// After one classify returns needsConfig, skip further LLM calls this run.
  bool _skipLlmForNeedsConfig = false;

  static const _rulesVersion = 'rules-v1';
  static const _rulesParser = RulesParser();
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

    _skipLlmForNeedsConfig = false;
    final rows = await _localDatabase.getUnprocessedRawIngests();
    var processed = 0;
    var transactionsCreated = 0;
    var skipped = 0;
    var failed = 0;
    var classifyNeedsConfig = false;
    String? classifyError;

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
          tx = await _maybeMatchPaymentSource(
            tx,
            ingest,
            sources,
            instrumentLast4: outcome.result.candidate?.instrumentLast4,
          );
          final classifyOutcome = await _maybeClassify(
            tx,
            body: ingest.body,
            sender: ingest.sender,
            categories: cats,
            sources: sources,
          );
          tx = classifyOutcome.transaction;
          if (classifyOutcome.needsConfig) classifyNeedsConfig = true;
          classifyError ??= classifyOutcome.error;
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

    final rematched = await _rematchUnmatchedTransactions(sources);
    final categoryMatched = await _reapplyLearnedCategoryRules(cats);
    final backlog = await _reclassifyPendingTransactions(sources, cats);

    return ParsePipelineResult(
      processed: processed,
      transactionsCreated: transactionsCreated,
      skipped: skipped,
      failed: failed,
      rematched: rematched,
      reclassified: categoryMatched + backlog.reclassified,
      classifyNeedsConfig: classifyNeedsConfig || backlog.classifyNeedsConfig,
      classifyError: backlog.classifyError ?? classifyError,
    );
  }

  /// Runs rematch + LLM backlog without processing new ingests (e.g. after
  /// saving Accounts). Safe to call from UI after payment source edits.
  Future<ParsePipelineResult> processBacklog({
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

    _skipLlmForNeedsConfig = false;
    final rematched = await _rematchUnmatchedTransactions(sources);
    final categoryMatched = await _reapplyLearnedCategoryRules(cats);
    final backlog = await _reclassifyPendingTransactions(sources, cats);
    return ParsePipelineResult(
      processed: 0,
      transactionsCreated: 0,
      skipped: 0,
      failed: 0,
      rematched: rematched,
      reclassified: categoryMatched + backlog.reclassified,
      classifyNeedsConfig: backlog.classifyNeedsConfig,
      classifyError: backlog.classifyError,
    );
  }

  /// Rules-first match using last4, sender hints, and SMS body before any LLM call.
  Future<Transaction> _maybeMatchPaymentSource(
    Transaction tx,
    RawIngest ingest,
    List<PaymentSource> sources, {
    String? instrumentLast4,
  }) async {
    final knownIds = sources.map((s) => s.id).toSet();
    if (!LocalDashboardRepository.isUnmatched(tx, knownIds)) return tx;

    final last4 =
        instrumentLast4 ?? _rulesParser.extractInstrumentLast4(ingest.body);
    final rulesMatch = matchPaymentSourceFromIngest(
      sender: ingest.sender,
      body: ingest.body,
      instrumentLast4: last4,
      merchant: tx.merchant,
      sources: sources,
    );
    if (rulesMatch == null) return tx;

    return tx.copyWith(paymentSourceId: rulesMatch, unmatched: false);
  }

  /// Re-applies payment-source rules to existing unmatched rows (e.g. after
  /// the user saves last4 in Accounts, or on Recovery re-sync).
  Future<int> _rematchUnmatchedTransactions(
    List<PaymentSource> sources,
  ) async {
    if (sources.isEmpty || !_authService.isSignedIn) return 0;

    final knownIds = sources.map((s) => s.id).toSet();
    final rows = await _localDatabase.getTransactionsNeedingSourceMatch();
    final uid = _authService.requireUid();
    var rematched = 0;

    for (final row in rows) {
      final tx = Transaction.fromSqlite(row);
      if (!LocalDashboardRepository.isUnmatched(tx, knownIds)) continue;

      final ingestRow = await _localDatabase.getRawIngest(tx.rawIngestId);
      if (ingestRow == null) continue;

      final body = ingestRow['body'] as String? ?? '';
      final sender = ingestRow['sender'] as String? ?? '';
      final last4 = _rulesParser.extractInstrumentLast4(body);
      final matchId = matchPaymentSourceFromIngest(
        sender: sender,
        body: body,
        instrumentLast4: last4,
        merchant: tx.merchant,
        sources: sources,
      );
      if (matchId == null || tx.id == null) continue;

      await _localDatabase.updateTransactionPaymentSource(tx.id!, matchId);
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(_transactionsCollection)
          .doc(tx.id)
          .set({
        'paymentSourceId': matchId,
        'unmatched': false,
      }, SetOptions(merge: true));
      rematched++;
    }
    if (rematched > 0) {
      debugPrint('IngestParsePipeline: rematched $rematched transaction(s)');
    }
    return rematched;
  }

  /// Applies user-taught merchant rules to backlog rows still awaiting category.
  Future<int> _reapplyLearnedCategoryRules(List<Category> categories) async {
    if (!_authService.isSignedIn) return 0;

    final rows = await _localDatabase.getFlaggedTransactions();
    final uid = _authService.requireUid();
    var matched = 0;

    for (final row in rows) {
      final tx = Transaction.fromSqlite(row);
      if (tx.classifiedBy == ClassifiedBy.user) continue;
      if (!tx.needsClassification && !tx.ambiguous) continue;
      if (tx.merchant == null || tx.merchant!.isEmpty) continue;

      String? categoryId;
      for (final category in categories) {
        if (category.matchMerchant(tx.merchant) != null) {
          categoryId = category.id;
          break;
        }
      }
      if (categoryId == null || tx.id == null) continue;

      final updated = tx.copyWith(
        categoryId: categoryId,
        needsClassification: false,
        ambiguous: false,
        classifiedBy: ClassifiedBy.rules,
      );
      await _persistTransaction(updated);
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(_transactionsCollection)
          .doc(tx.id)
          .set({
        'categoryId': categoryId,
        'needsClassification': false,
        'ambiguous': false,
        'classifiedBy': ClassifiedBy.rules.name,
      }, SetOptions(merge: true));
      matched++;
    }

    if (matched > 0) {
      debugPrint(
        'IngestParsePipeline: category rules matched $matched transaction(s)',
      );
    }
    return matched;
  }

  /// Re-runs LLM classify on backlog rows still in Review (e.g. after Gemini
  /// secret is set, or when payment sources were added after first parse).
  Future<ParsePipelineResult> _reclassifyPendingTransactions(
    List<PaymentSource> sources,
    List<Category> categories,
  ) async {
    if (!_authService.isSignedIn) {
      return const ParsePipelineResult(
        processed: 0,
        transactionsCreated: 0,
        skipped: 0,
        failed: 0,
      );
    }

    final knownIds = sources.map((s) => s.id).toSet();
    final rows = await _localDatabase.getFlaggedTransactions();
    var reclassified = 0;
    var classifyNeedsConfig = false;
    String? classifyError;

    for (final row in rows) {
      final tx = Transaction.fromSqlite(row);
      if (tx.classifiedBy == ClassifiedBy.user) continue;

      final needsCategory = tx.needsClassification || tx.ambiguous;
      final needsSource =
          LocalDashboardRepository.isUnmatched(tx, knownIds) &&
              sources.isNotEmpty;
      if (!needsCategory && !needsSource) continue;

      final ingestRow = await _localDatabase.getRawIngest(tx.rawIngestId);
      if (ingestRow == null) continue;

      final body = ingestRow['body'] as String? ?? '';
      final sender = ingestRow['sender'] as String? ?? '';
      final classifyOutcome = await _maybeClassify(
        tx,
        body: body,
        sender: sender,
        categories: categories,
        sources: sources,
      );

      if (!classifyOutcome.applied) {
        if (classifyOutcome.needsConfig) classifyNeedsConfig = true;
        classifyError ??= classifyOutcome.error;
        continue;
      }

      await _persistTransaction(classifyOutcome.transaction);
      reclassified++;
    }

    if (reclassified > 0) {
      debugPrint('IngestParsePipeline: LLM reclassified $reclassified row(s)');
    }
    ClassifierDiagnostics.recordAttempt(
      needsConfig: classifyNeedsConfig,
      error: classifyError,
      successCount: reclassified,
    );

    return ParsePipelineResult(
      processed: 0,
      transactionsCreated: 0,
      skipped: 0,
      failed: 0,
      reclassified: reclassified,
      classifyNeedsConfig: classifyNeedsConfig,
      classifyError: classifyError,
    );
  }

  /// Rules-first LLM gate for category and payment-source assignment.
  ///
  /// Invoked when a debit still [needsClassification], is [ambiguous], or the
  /// payment source is unmatched. Calls [TransactionClassifier] (typically
  /// [CloudFunctionsClassifier] → `classifyTransaction` / Gemini). When the
  /// backend returns `needsConfig: true` (no `GEMINI_API_KEY` secret), the
  /// transaction stays in the in-app Review inbox — redeploy after setting the
  /// secret: `firebase functions:secrets:set GEMINI_API_KEY`.
  Future<_ClassifyOutcome> _maybeClassify(
    Transaction tx, {
    required String body,
    required String sender,
    required List<Category> categories,
    required List<PaymentSource> sources,
  }) async {
    final knownIds = sources.map((s) => s.id).toSet();
    final needsCategory = tx.needsClassification || tx.ambiguous;
    final needsSource =
        LocalDashboardRepository.isUnmatched(tx, knownIds) && sources.isNotEmpty;
    if (!needsCategory && !needsSource) {
      return _ClassifyOutcome(transaction: tx);
    }

    if (_skipLlmForNeedsConfig) {
      return _ClassifyOutcome(transaction: tx, needsConfig: true);
    }

    final result = await _classifier.classify(
      transaction: tx,
      smsBody: body,
      smsSender: sender,
      categoryIds: categories.map((c) => c.id).toList(),
      subcategoryTaxonomy: subcategoryTaxonomyForLlm(),
      paymentSources: sources,
      includePaymentSources: needsSource,
      includeSubcategoryTaxonomy: needsCategory,
    );
    if (result == null) {
      return _ClassifyOutcome(transaction: tx);
    }
    if (result.errorMessage != null) {
      debugPrint(
        'IngestParsePipeline: classify failed for ${tx.id}: ${result.errorMessage}',
      );
      ClassifierDiagnostics.recordAttempt(error: result.errorMessage);
      return _ClassifyOutcome(
        transaction: tx,
        error: result.errorMessage,
      );
    }
    if (result.needsConfig) {
      _skipLlmForNeedsConfig = true;
      ClassifierDiagnostics.recordAttempt(
        needsConfig: true,
        error: 'GEMINI_API_KEY not set on Cloud Functions',
      );
      return _ClassifyOutcome(transaction: tx, needsConfig: true);
    }

    final updated = ClassificationApplier.apply(
      tx: tx,
      result: result,
      categories: categories,
      knownSourceIds: knownIds,
      forceCategory: needsCategory,
      forceSource: needsSource,
    );
    return _ClassifyOutcome(
      transaction: updated,
      applied: updated != tx,
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
      'subcategory_id': tx.subcategoryId,
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
      'travel_provider': tx.travelProvider,
      'transfer_to': tx.transferTo,
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
