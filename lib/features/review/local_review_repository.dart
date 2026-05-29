import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/transaction.dart';

import '../../core/auth/auth_service.dart';
import '../../core/db/local_database.dart';
import '../../services/category_service.dart';
import 'review_repository.dart';

/// Review queue backed by local SQLite with Firestore sync on relabel.
class LocalReviewRepository implements ReviewRepository {
  LocalReviewRepository({
    required LocalDatabase localDatabase,
    required AuthService authService,
    required CategoryService categoryService,
    FirebaseFirestore? firestore,
  })  : _db = localDatabase,
        _authService = authService,
        _categories = categoryService,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final LocalDatabase _db;
  final AuthService _authService;
  final CategoryService _categories;
  final FirebaseFirestore _firestore;

  @override
  Future<List<Transaction>> flaggedTransactions() async {
    final rows = await _db.getFlaggedTransactions();
    return rows.map(_transactionFromRow).toList();
  }

  @override
  Future<List<Category>> availableCategories() => _categories.loadCategories();

  @override
  Future<void> relabel({
    required String transactionId,
    required String categoryId,
    String? merchantRuleHint,
  }) async {
    await _db.updateTransactionFlags(
      transactionId,
      categoryId: categoryId,
      ambiguous: false,
    );

    final uid = _authService.requireUid();
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(transactionId)
        .update({
      'categoryId': categoryId,
      'ambiguous': false,
    });
  }

  Transaction _transactionFromRow(Map<String, dynamic> row) {
    return Transaction(
      id: row['id'] as String?,
      rawIngestId: row['raw_ingest_id'] as String? ?? '',
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      currency: row['currency'] as String? ?? 'INR',
      merchant: row['merchant'] as String?,
      timestamp: DateTime.parse(row['timestamp'] as String),
      categoryId: row['category_id'] as String?,
      paymentSourceId: row['payment_source_id'] as String?,
      unmatched: (row['unmatched'] as int? ?? 0) == 1,
      ambiguous: (row['ambiguous'] as int? ?? 0) == 1,
      type: TransactionType.fromString(row['type'] as String? ?? 'debit'),
    );
  }
}
