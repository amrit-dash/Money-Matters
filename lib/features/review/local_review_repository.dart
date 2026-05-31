import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/transaction.dart';

import '../../core/auth/auth_service.dart';
import '../../core/db/local_database.dart';
import '../../services/category_service.dart';
import 'review_repository.dart';

/// Review queue backed by local SQLite with Firestore sync on classify.
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
    return rows.map(Transaction.fromSqlite).toList();
  }

  @override
  Future<List<Category>> availableCategories() => _categories.loadCategories();

  @override
  Future<Transaction?> transactionById(String id) async {
    final row = await _db.getTransaction(id);
    if (row == null) return null;
    return Transaction.fromSqlite(row);
  }

  @override
  Future<int> needsInputCount() => _db.countNeedsClassification();

  @override
  Future<void> classify({
    required Transaction transaction,
    required ClassifyInput input,
  }) async {
    final id = transaction.id;
    if (id == null) {
      throw StateError('Cannot classify a transaction without an id');
    }

    await _db.updateTransactionClassification(
      id,
      categoryId: input.categoryId,
      userNotes: input.userNotes,
      shoppingItems: input.shoppingItems,
      classifiedBy: ClassifiedBy.user.name,
      needsClassification: false,
      ambiguous: false,
    );

    final uid = _authService.requireUid();
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(id)
        .set({
      'categoryId': input.categoryId,
      'ambiguous': false,
      'needsClassification': false,
      'classifiedBy': ClassifiedBy.user.name,
      if (input.userNotes != null) 'userNotes': input.userNotes,
      if (input.shoppingItems.isNotEmpty) 'shoppingItems': input.shoppingItems,
    }, SetOptions(merge: true));

    // Teach a user-specific merchant rule so future SMS auto-categorize.
    if (input.saveMerchantRule) {
      final merchant = transaction.merchant;
      if (merchant != null && merchant.isNotEmpty) {
        await _categories.addMerchantRule(
          categoryId: input.categoryId,
          merchant: merchant,
        );
      }
    }
  }

  @override
  Future<void> relabel({
    required String transactionId,
    required String categoryId,
    String? merchantRuleHint,
  }) async {
    final tx = await transactionById(transactionId) ??
        Transaction(
          id: transactionId,
          rawIngestId: '',
          amount: 0,
          timestamp: DateTime.now(),
          type: TransactionType.debit,
          merchant: merchantRuleHint,
        );
    await classify(
      transaction: tx,
      input: ClassifyInput(
        categoryId: categoryId,
        saveMerchantRule: merchantRuleHint != null,
      ),
    );
  }

  DocumentReference<Map<String, dynamic>> _transactionDoc(String id) {
    final uid = _authService.requireUid();
    return _firestore.collection('users').doc(uid).collection('transactions').doc(id);
  }

  @override
  Future<void> excludeTransaction(String transactionId) async {
    await _db.updateTransactionExcluded(transactionId, excluded: true);

    try {
      await _transactionDoc(transactionId).set({
        'excluded': true,
        'needsClassification': false,
        'ambiguous': false,
      }, SetOptions(merge: true));
    } catch (_) {
      // Offline or unsigned — local exclusion still applies.
    }
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    await _db.deleteTransaction(transactionId);

    try {
      await _transactionDoc(transactionId).delete();
    } catch (_) {
      // Offline or unsigned — local delete still applies.
    }
  }
}
