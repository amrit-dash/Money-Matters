import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/transaction.dart';

import '../../core/auth/auth_service.dart';
import '../../core/db/local_database.dart';
import '../../core/db/local_data_streams.dart';
import '../../parse/rules_parser.dart';
import '../../services/category_service.dart';
import '../../services/ingest_parse_pipeline.dart';
import '../../services/payment_source_service.dart';
import 'review_repository.dart';

/// Review queue backed by local SQLite with Firestore sync on classify.
class LocalReviewRepository implements ReviewRepository {
  LocalReviewRepository({
    required LocalDatabase localDatabase,
    required AuthService authService,
    required CategoryService categoryService,
    PaymentSourceService? paymentSourceService,
    IngestParsePipeline? parsePipeline,
    FirebaseFirestore? firestore,
  })  : _db = localDatabase,
        _authService = authService,
        _categories = categoryService,
        _paymentSources = paymentSourceService,
        _parsePipeline = parsePipeline,
        _firestore = firestore ?? FirebaseFirestore.instance;

  static const _rulesParser = RulesParser();

  final LocalDatabase _db;
  final AuthService _authService;
  final CategoryService _categories;
  final PaymentSourceService? _paymentSources;
  final IngestParsePipeline? _parsePipeline;
  final FirebaseFirestore _firestore;

  @override
  Future<List<Transaction>> flaggedTransactions() async {
    final rows = await _db.getFlaggedTransactions();
    return rows.map(Transaction.fromSqlite).toList();
  }

  @override
  Stream<List<Transaction>> watchFlaggedTransactions() {
    return watchLocalData(
      _db.transactionChanges,
      flaggedTransactions,
    );
  }

  @override
  Future<List<Category>> availableCategories() => _categories.loadCategories();

  @override
  Stream<List<Category>> watchAvailableCategories() =>
      _categories.watchCategories();

  @override
  Future<Transaction?> transactionById(String id) async {
    final row = await _db.getTransaction(id);
    if (row == null) return null;
    return Transaction.fromSqlite(row);
  }

  @override
  Stream<Transaction?> watchTransaction(String id) {
    return watchLocalData(
      _db.transactionChanges,
      () => transactionById(id),
    );
  }

  @override
  Future<int> needsInputCount() => _db.countNeedsClassification();

  @override
  Stream<int> watchNeedsInputCount() {
    return watchLocalData(
      _db.transactionChanges,
      needsInputCount,
    );
  }

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
      subcategoryId: input.subcategoryId,
      merchantNormalized: input.merchantNormalized,
      userNotes: input.userNotes,
      shoppingItems: input.shoppingItems,
      travelProvider: input.travelProvider,
      transferTo: input.transferTo,
      classifiedBy: ClassifiedBy.user.name,
      needsClassification: false,
      ambiguous: false,
    );

    final paymentSourceId = input.paymentSourceId;
    if (paymentSourceId != null) {
      await _db.updateTransactionPaymentSource(id, paymentSourceId);
    }

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
      if (input.subcategoryId != null && input.subcategoryId!.isNotEmpty)
        'subcategoryId': input.subcategoryId,
      if (input.subcategoryId != null && input.subcategoryId!.isEmpty)
        'subcategoryId': FieldValue.delete(),
      if (input.merchantNormalized != null)
        'merchantNormalized': input.merchantNormalized,
      if (input.userNotes != null) 'userNotes': input.userNotes,
      if (input.shoppingItems.isNotEmpty) 'shoppingItems': input.shoppingItems,
      if (input.travelProvider != null && input.travelProvider!.isNotEmpty)
        'travelProvider': input.travelProvider,
      if (input.transferTo != null && input.transferTo!.isEmpty)
        'transferTo': FieldValue.delete(),
      if (input.transferTo != null && input.transferTo!.isNotEmpty)
        'transferTo': input.transferTo,
      if (paymentSourceId != null) ...{
        'paymentSourceId': paymentSourceId,
        'unmatched': false,
      },
    }, SetOptions(merge: true));

    var learnedRules = false;

    // Teach a user-specific merchant rule so future SMS auto-categorize.
    if (input.saveMerchantRule) {
      final merchant = transaction.merchant;
      if (merchant != null && merchant.isNotEmpty) {
        await _categories.addMerchantRule(
          categoryId: input.categoryId,
          merchant: merchant,
        );
        learnedRules = true;
      }
    }

    if (paymentSourceId != null) {
      final ingestRow = await _db.getRawIngest(transaction.rawIngestId);
      if (ingestRow != null) {
        final body = ingestRow['body'] as String? ?? '';
        final sender = ingestRow['sender'] as String? ?? '';
        final last4 = _rulesParser.extractInstrumentLast4(body);
        await _paymentSources?.learnFromTransaction(
          paymentSourceId: paymentSourceId,
          sender: sender,
          body: body,
          merchant: transaction.merchant,
          instrumentLast4: last4,
        );
        learnedRules = true;
      }
    }

    if (learnedRules) {
      await _parsePipeline?.processBacklog();
    }
  }

  @override
  Future<void> updatePaymentSource({
    required String transactionId,
    required String paymentSourceId,
  }) async {
    await _db.updateTransactionPaymentSource(transactionId, paymentSourceId);

    final uid = _authService.requireUid();
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(transactionId)
        .set({
      'paymentSourceId': paymentSourceId,
      'unmatched': false,
    }, SetOptions(merge: true));

    final tx = await transactionById(transactionId);
    if (tx == null) return;

    final ingestRow = await _db.getRawIngest(tx.rawIngestId);
    if (ingestRow == null) return;

    final body = ingestRow['body'] as String? ?? '';
    final sender = ingestRow['sender'] as String? ?? '';
    final last4 = _rulesParser.extractInstrumentLast4(body);
    await _paymentSources?.learnFromTransaction(
      paymentSourceId: paymentSourceId,
      sender: sender,
      body: body,
      merchant: tx.merchant,
      instrumentLast4: last4,
    );
    _categories.invalidateCache();
    await _parsePipeline?.processBacklog();
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
  Future<void> persistAiClassification(Transaction transaction) async {
    final id = transaction.id;
    if (id == null) {
      throw StateError('Cannot persist AI classification without an id');
    }

    await _db.updateTransactionClassification(
      id,
      categoryId: transaction.categoryId,
      subcategoryId: transaction.subcategoryId,
      merchantNormalized: transaction.merchantNormalized,
      userNotes: transaction.userNotes,
      shoppingItems: transaction.shoppingItems,
      travelProvider: transaction.travelProvider,
      transferTo: transaction.transferTo,
      classifiedBy: ClassifiedBy.llm.name,
      needsClassification: transaction.needsClassification,
      ambiguous: transaction.ambiguous,
    );

    if (transaction.paymentSourceId != null) {
      await _db.updateTransactionPaymentSource(
        id,
        transaction.paymentSourceId!,
      );
    }

    final uid = _authService.requireUid();
    await _firestore.collection('users').doc(uid).collection('transactions').doc(id).set({
      if (transaction.categoryId != null) 'categoryId': transaction.categoryId,
      if (transaction.subcategoryId != null &&
          transaction.subcategoryId!.isNotEmpty)
        'subcategoryId': transaction.subcategoryId,
      'ambiguous': transaction.ambiguous,
      'needsClassification': transaction.needsClassification,
      'classifiedBy': ClassifiedBy.llm.name,
      if (transaction.merchantNormalized != null)
        'merchantNormalized': transaction.merchantNormalized,
      if (transaction.userNotes != null) 'userNotes': transaction.userNotes,
      if (transaction.shoppingItems.isNotEmpty)
        'shoppingItems': transaction.shoppingItems,
      if (transaction.travelProvider != null &&
          transaction.travelProvider!.isNotEmpty)
        'travelProvider': transaction.travelProvider,
      if (transaction.transferTo != null && transaction.transferTo!.isNotEmpty)
        'transferTo': transaction.transferTo,
      if (transaction.merchant != null) 'merchant': transaction.merchant,
      if (transaction.paymentSourceId != null) ...{
        'paymentSourceId': transaction.paymentSourceId,
        'unmatched': transaction.unmatched,
      },
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    await _db.deleteTransaction(transactionId);

    try {
      // Tombstone so Firestore drain does not resurrect this transaction.
      await _transactionDoc(transactionId).set({
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _transactionDoc(transactionId).delete();
    } catch (_) {
      // Offline or unsigned — local delete + deleted_transactions still apply.
    }
  }
}
