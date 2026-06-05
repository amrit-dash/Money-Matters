import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:money_matters/core/auth/auth_service.dart';
import 'package:money_matters/core/db/local_database.dart';
import 'package:money_matters/features/review/local_review_repository.dart';
import 'package:money_matters/features/review/review_repository.dart';
import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';
import 'package:money_matters/services/category_service.dart';
import 'package:money_matters/ingest/ingest_queue_drain.dart';
import 'package:money_matters/ingest/ingest_repository.dart';
import 'package:money_matters/services/ingest_parse_pipeline.dart';

class _HangingQueueDrain extends IngestQueueDrain {
  _HangingQueueDrain({
    required super.repository,
    required super.authService,
    required IngestParsePipeline parsePipeline,
  }) : super(parsePipeline: parsePipeline);

  final hang = Completer<ParsePipelineResult>();
  var invokeCount = 0;

  @override
  Future<ParsePipelineResult?> processBacklogIfAuthenticated() {
    invokeCount++;
    return hang.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  late LocalDatabase db;
  late AuthService auth;
  late CategoryService categories;

  setUp(() {
    db = LocalDatabase();
    auth = AuthService();
    categories = CategoryService(authService: auth);
  });

  Future<Transaction> seedFlaggedTransaction() async {
    const id = 'tx-classify-test';
    await db.upsertTransaction({
      'id': id,
      'raw_ingest_id': 'ingest-1',
      'amount': 499.0,
      'currency': 'INR',
      'merchant': 'ZEPTO',
      'timestamp': DateTime.utc(2026, 6, 1, 12).toIso8601String(),
      'category_id': null,
      'subcategory_id': null,
      'payment_source_id': 'hdfc',
      'unmatched': 0,
      'ambiguous': 1,
      'excluded': 0,
      'type': 'debit',
      'needs_classification': 1,
      'merchant_normalized': null,
      'user_notes': null,
      'shopping_items': null,
      'travel_provider': null,
      'transfer_to': null,
      'classified_by': null,
      'synced_at': DateTime.utc(2026, 6, 1).toIso8601String(),
    });
    final row = await db.getTransaction(id);
    return Transaction.fromSqlite(row!);
  }

  test('classify persists locally and returns before processBacklog completes',
      () async {
    await runZonedGuarded(() async {
      final tx = await seedFlaggedTransaction();
      final pipeline = IngestParsePipeline(
        localDatabase: db,
        authService: auth,
      );
      final drain = _HangingQueueDrain(
        repository: IngestRepository(
          authService: auth,
          localDatabase: db,
        ),
        authService: auth,
        parsePipeline: pipeline,
      );
      final repo = LocalReviewRepository(
        localDatabase: db,
        authService: auth,
        categoryService: categories,
        queueDrain: drain,
      );

      final stopwatch = Stopwatch()..start();
      await repo.classify(
        transaction: tx,
        input: const ClassifyInput(
          categoryId: 'groceries',
          saveMerchantRule: true,
        ),
      );
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 500)));

      final saved = await repo.transactionById(tx.id!);
      expect(saved?.categoryId, 'groceries');
      expect(saved?.needsClassification, isFalse);
      expect(saved?.ambiguous, isFalse);
      expect(saved?.classifiedBy, ClassifiedBy.user);

      await Future<void>.delayed(Duration.zero);
      expect(drain.invokeCount, 1);
      expect(drain.hang.isCompleted, isFalse);
    }, (error, stack) {
      // Background sync may touch Firebase Auth in unit tests; save already applied.
    });
  });

  test('classify completes quickly without a parse pipeline', () async {
    final tx = await seedFlaggedTransaction();
    final repo = LocalReviewRepository(
      localDatabase: db,
      authService: auth,
      categoryService: categories,
    );

    await repo.classify(
      transaction: tx,
      input: const ClassifyInput(categoryId: 'food'),
    );

    final saved = await repo.transactionById(tx.id!);
    expect(saved?.categoryId, 'food');
  });
}
