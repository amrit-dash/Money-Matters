import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite mirror for Firestore ingest and transaction data.
class LocalDatabase {
  LocalDatabase();

  static const _dbName = 'money_matters.db';
  static const _dbVersion = 7;

  Database? _db;
  final StreamController<void> _transactionChanges =
      StreamController<void>.broadcast();

  /// Fires after any local transaction row is inserted, updated, or deleted.
  Stream<void> get transactionChanges => _transactionChanges.stream;

  void _notifyTransactionChanged() {
    if (!_transactionChanges.isClosed) {
      _transactionChanges.add(null);
    }
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      singleInstance: true,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE raw_ingests (
        idempotency_key TEXT PRIMARY KEY,
        body TEXT NOT NULL,
        sender TEXT NOT NULL,
        received_at TEXT NOT NULL,
        device_id TEXT,
        source TEXT NOT NULL,
        batch_hint TEXT,
        created_at TEXT,
        duplicate INTEGER NOT NULL DEFAULT 0,
        processed_at TEXT,
        synced_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE parse_jobs (
        id TEXT PRIMARY KEY,
        raw_ingest_id TEXT NOT NULL,
        status TEXT NOT NULL,
        rules_version TEXT,
        error TEXT,
        updated_at TEXT,
        synced_at TEXT NOT NULL,
        FOREIGN KEY (raw_ingest_id) REFERENCES raw_ingests(idempotency_key)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_parse_jobs_status ON parse_jobs(status)
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        raw_ingest_id TEXT,
        amount REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'INR',
        merchant TEXT,
        timestamp TEXT NOT NULL,
        category_id TEXT,
        subcategory_id TEXT,
        payment_source_id TEXT,
        unmatched INTEGER NOT NULL DEFAULT 0,
        ambiguous INTEGER NOT NULL DEFAULT 0,
        excluded INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL,
        needs_classification INTEGER NOT NULL DEFAULT 0,
        merchant_normalized TEXT,
        user_notes TEXT,
        shopping_items TEXT,
        travel_provider TEXT,
        transfer_to TEXT,
        classified_by TEXT,
        synced_at TEXT NOT NULL,
        FOREIGN KEY (raw_ingest_id) REFERENCES raw_ingests(idempotency_key)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_timestamp ON transactions(timestamp)
    ''');
    await db.execute('''
      CREATE INDEX idx_transactions_payment_source
        ON transactions(payment_source_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_transactions_needs_classification
        ON transactions(needs_classification)
    ''');

    await db.execute('''
      CREATE TABLE deleted_transactions (
        id TEXT PRIMARY KEY,
        deleted_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: classification + LLM/HITL fields on transactions.
      const columns = <String, String>{
        'needs_classification': 'INTEGER NOT NULL DEFAULT 0',
        'merchant_normalized': 'TEXT',
        'user_notes': 'TEXT',
        'shopping_items': 'TEXT',
        'classified_by': 'TEXT',
      };
      for (final entry in columns.entries) {
        try {
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN ${entry.key} ${entry.value}',
          );
        } catch (_) {
          // Column already present (idempotent upgrade) — ignore.
        }
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_payment_source '
        'ON transactions(payment_source_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_needs_classification '
        'ON transactions(needs_classification)',
      );
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN excluded INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {
        // Column already present (idempotent upgrade) — ignore.
      }
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS deleted_transactions (
          id TEXT PRIMARY KEY,
          deleted_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN travel_provider TEXT',
        );
      } catch (_) {
        // Column already present (idempotent upgrade) — ignore.
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN transfer_to TEXT',
        );
      } catch (_) {
        // Column already present (idempotent upgrade) — ignore.
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN subcategory_id TEXT',
        );
      } catch (_) {
        // Column already present (idempotent upgrade) — ignore.
      }
    }
  }

  // --- raw_ingests ---

  Future<void> upsertRawIngest(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert(
      'raw_ingests',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getRawIngest(String idempotencyKey) async {
    final db = await database;
    final rows = await db.query(
      'raw_ingests',
      where: 'idempotency_key = ?',
      whereArgs: [idempotencyKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getUnprocessedRawIngests() async {
    final db = await database;
    return db.query(
      'raw_ingests',
      where: 'processed_at IS NULL',
      orderBy: 'received_at ASC',
    );
  }

  Future<int> countPendingRawIngests() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM raw_ingests WHERE processed_at IS NULL',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countRawIngests() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM raw_ingests');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markRawIngestProcessed(String idempotencyKey) async {
    final db = await database;
    await db.update(
      'raw_ingests',
      {'processed_at': DateTime.now().toUtc().toIso8601String()},
      where: 'idempotency_key = ?',
      whereArgs: [idempotencyKey],
    );
  }

  // --- parse_jobs ---

  Future<void> upsertParseJob(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert(
      'parse_jobs',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getParseJob(String id) async {
    final db = await database;
    final rows = await db.query(
      'parse_jobs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getPendingParseJobs() async {
    final db = await database;
    return db.query(
      'parse_jobs',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'updated_at ASC',
    );
  }

  Future<int> countPendingParseJobs() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM parse_jobs WHERE status = 'pending'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // --- transactions ---

  Future<void> upsertTransaction(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert(
      'transactions',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifyTransactionChanged();
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await database;
    return db.query('transactions', orderBy: 'timestamp DESC');
  }

  Future<int> countTransactions() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM transactions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getTransactionsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    return db.query(
      'transactions',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String(),
      ],
      orderBy: 'timestamp DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getFlaggedTransactions() async {
    final db = await database;
    return db.query(
      'transactions',
      where:
          'excluded = 0 AND (ambiguous = 1 OR unmatched = 1 OR needs_classification = 1)',
      orderBy: 'timestamp DESC',
    );
  }

  /// Unmatched or source-less transactions eligible for payment-source rematch.
  Future<List<Map<String, dynamic>>> getTransactionsNeedingSourceMatch() async {
    final db = await database;
    return db.query(
      'transactions',
      where: 'excluded = 0 AND (unmatched = 1 OR payment_source_id IS NULL)',
      orderBy: 'timestamp DESC',
    );
  }

  Future<void> updateTransactionPaymentSource(
    String id,
    String paymentSourceId,
  ) async {
    final db = await database;
    await db.update(
      'transactions',
      {
        'payment_source_id': paymentSourceId,
        'unmatched': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyTransactionChanged();
  }

  Future<Map<String, dynamic>?> getTransaction(String id) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getTransactionsForSource(
    String? paymentSourceId,
  ) async {
    final db = await database;
    if (paymentSourceId == null) {
      // Unmatched bucket is filtered in Dart via [LocalDashboardRepository.isUnmatched]
      // so orphaned payment_source_id refs (deleted accounts) are included.
      return db.query(
        'transactions',
        where: 'excluded = 0',
        orderBy: 'timestamp DESC',
      );
    }
    return db.query(
      'transactions',
      where: 'excluded = 0 AND payment_source_id = ?',
      whereArgs: [paymentSourceId],
      orderBy: 'timestamp DESC',
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    final deletedAt = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.insert(
        'deleted_transactions',
        {'id': id, 'deleted_at': deletedAt},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    _notifyTransactionChanged();
  }

  Future<bool> isTransactionDeleted(String id) async {
    final db = await database;
    final rows = await db.query(
      'deleted_transactions',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> updateTransactionExcluded(String id, {required bool excluded}) async {
    final db = await database;
    await db.update(
      'transactions',
      {
        'excluded': excluded ? 1 : 0,
        if (excluded) ...{
          'needs_classification': 0,
          'ambiguous': 0,
        },
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyTransactionChanged();
  }

  /// Transactions still awaiting user/LLM categorization (uncategorized,
  /// ambiguous, or unmatched) — powers the in-app "Needs your input" inbox.
  Future<int> countNeedsClassification() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions '
      'WHERE excluded = 0 AND (needs_classification = 1 OR ambiguous = 1 OR unmatched = 1)',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> updateTransactionFlags(
    String id, {
    String? categoryId,
    bool? ambiguous,
    bool? unmatched,
  }) async {
    final db = await database;
    final updates = <String, Object?>{};
    if (categoryId != null) updates['category_id'] = categoryId;
    if (ambiguous != null) updates['ambiguous'] = ambiguous ? 1 : 0;
    if (unmatched != null) updates['unmatched'] = unmatched ? 1 : 0;
    if (updates.isEmpty) return;
    await db.update(
      'transactions',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyTransactionChanged();
  }

  /// Applies a classification result (from user relabel or LLM) locally.
  Future<void> updateTransactionClassification(
    String id, {
    String? categoryId,
    String? subcategoryId,
    String? merchantNormalized,
    String? userNotes,
    List<String>? shoppingItems,
    String? travelProvider,
    String? transferTo,
    String? classifiedBy,
    bool? needsClassification,
    bool? ambiguous,
  }) async {
    final db = await database;
    final updates = <String, Object?>{};
    if (categoryId != null) updates['category_id'] = categoryId;
    if (subcategoryId != null) {
      updates['subcategory_id'] =
          subcategoryId.isEmpty ? null : subcategoryId;
    }
    if (merchantNormalized != null) {
      updates['merchant_normalized'] = merchantNormalized;
    }
    if (userNotes != null) updates['user_notes'] = userNotes;
    if (shoppingItems != null) {
      updates['shopping_items'] = jsonEncode(shoppingItems);
    }
    if (travelProvider != null) {
      updates['travel_provider'] =
          travelProvider.isEmpty ? null : travelProvider;
    }
    if (transferTo != null) {
      updates['transfer_to'] = transferTo.isEmpty ? null : transferTo;
    }
    if (classifiedBy != null) updates['classified_by'] = classifiedBy;
    if (needsClassification != null) {
      updates['needs_classification'] = needsClassification ? 1 : 0;
    }
    if (ambiguous != null) updates['ambiguous'] = ambiguous ? 1 : 0;
    if (updates.isEmpty) return;
    await db.update(
      'transactions',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyTransactionChanged();
  }

  Future<DateTime?> getLatestRawIngestTime() async {
    final db = await database;
    final rows = await db.query(
      'raw_ingests',
      orderBy: 'received_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['received_at'] as String? ?? '');
  }

  /// Wipes all local ledger rows (ingests, jobs, transactions, tombstones).
  Future<void> clearAllUserData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('raw_ingests');
      await txn.delete('parse_jobs');
      await txn.delete('deleted_transactions');
    });
    _notifyTransactionChanged();
  }

  Future<void> close() async {
    await _transactionChanges.close();
    await _db?.close();
    _db = null;
  }
}
