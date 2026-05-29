import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite mirror for Firestore ingest and transaction data.
class LocalDatabase {
  LocalDatabase();

  static const _dbName = 'money_matters.db';
  static const _dbVersion = 1;

  Database? _db;

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
        payment_source_id TEXT,
        unmatched INTEGER NOT NULL DEFAULT 0,
        ambiguous INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL,
        synced_at TEXT NOT NULL,
        FOREIGN KEY (raw_ingest_id) REFERENCES raw_ingests(idempotency_key)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_timestamp ON transactions(timestamp)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations handled by coordinator.
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
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await database;
    return db.query('transactions', orderBy: 'timestamp DESC');
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
      where: 'ambiguous = 1 OR unmatched = 1',
      orderBy: 'timestamp DESC',
    );
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

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
