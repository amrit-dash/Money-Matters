import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/category_taxonomy.dart';
import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';

import '../core/db/local_database.dart';
import '../parse/llm_parser.dart';
import 'classification_applier.dart';
import 'category_service.dart';
import 'payment_source_service.dart';

/// UI-facing AI classify: loads SMS context, calls [TransactionClassifier].
class AiClassifyService {
  AiClassifyService({
    TransactionClassifier? classifier,
    required LocalDatabase localDatabase,
    required CategoryService categoryService,
    required PaymentSourceService paymentSourceService,
  })  : _classifier = classifier ?? CloudFunctionsClassifier(),
        _db = localDatabase,
        _categories = categoryService,
        _paymentSources = paymentSourceService;

  final TransactionClassifier _classifier;
  final LocalDatabase _db;
  final CategoryService _categories;
  final PaymentSourceService _paymentSources;

  /// User-typed description from Inbox classify (explicit confirmation).
  Future<AiClassifyFormUpdate> classifyFromUserText(
    Transaction tx,
    String userText, {
    String? selectedCategoryId,
  }) async {
    final trimmed = userText.trim();
    if (trimmed.isEmpty) {
      return const AiClassifyFormUpdate(errorMessage: 'Enter a description first');
    }
    final categories = await _categories.loadCategories();
    final sources = await _paymentSources.loadAll();
    final result = await _classify(
      tx,
      categories,
      sources,
      selectedCategoryId: selectedCategoryId,
      userDescription: trimmed,
    );
    return _mapToFormUpdate(tx, result, categories, sources,
        selectedCategoryId: selectedCategoryId,
        allowLlmNotes: true,
        applyCategorySuggestions: true);
  }

  Future<AiClassifyFormUpdate> suggestForForm(
    Transaction tx, {
    String? selectedCategoryId,
    String? selectedSubcategoryId,
  }) async {
    final categories = await _categories.loadCategories();
    final sources = await _paymentSources.loadAll();
    final result = await _classify(
      tx,
      categories,
      sources,
      selectedCategoryId: selectedCategoryId,
    );
    return _mapToFormUpdate(
      tx,
      result,
      categories,
      sources,
      selectedCategoryId: selectedCategoryId,
      selectedSubcategoryId: selectedSubcategoryId,
    );
  }

  AiClassifyFormUpdate _mapToFormUpdate(
    Transaction tx,
    ClassificationResult? result,
    List<Category> categories,
    List<PaymentSource> sources, {
    String? selectedCategoryId,
    String? selectedSubcategoryId,
    bool allowLlmNotes = false,
    bool applyCategorySuggestions = false,
  }) {
    if (result == null) {
      return const AiClassifyFormUpdate();
    }
    if (result.needsConfig) {
      return const AiClassifyFormUpdate(needsConfig: true);
    }
    if (result.errorMessage != null) {
      return AiClassifyFormUpdate(errorMessage: result.errorMessage);
    }

    final knownIds = sources.map((s) => s.id).toSet();
    final updated = ClassificationApplier.apply(
      tx: tx,
      result: result,
      categories: categories,
      knownSourceIds: knownIds,
      forceCategory: applyCategorySuggestions,
      forceSource: true,
      selectedCategoryId: selectedCategoryId,
      allowLlmNotes: allowLlmNotes,
    );

    return AiClassifyFormUpdate(
      categoryId: applyCategorySuggestions
          ? updated.categoryId
          : (result.categoryId != null && !result.needsUserInput
              ? result.categoryId
              : null),
      paymentSourceId: updated.paymentSourceId,
      merchantNormalized: updated.merchantNormalized,
      merchant: updated.merchant != tx.merchant ? updated.merchant : null,
      subcategoryId: updated.subcategoryId ?? selectedSubcategoryId,
      userNotes: allowLlmNotes ? updated.userNotes : null,
      shoppingItems: updated.shoppingItems,
      travelProvider: updated.travelProvider,
      transferTo: updated.transferTo,
      suggestedCategoryId: result.suggestedCategoryId,
      suggestedCategoryName: result.suggestedCategoryName,
      needsUserInput: result.needsUserInput,
    );
  }

  /// Applies AI result to [tx] and returns the updated transaction (in-memory).
  Future<({Transaction? transaction, bool needsConfig, String? error})>
      applyToTransaction(Transaction tx) async {
    final categories = await _categories.loadCategories();
    final sources = await _paymentSources.loadAll();
    final result = await _classify(tx, categories, sources);
    if (result == null) {
      return (transaction: tx, needsConfig: false, error: null);
    }
    if (result.needsConfig) {
      return (transaction: null, needsConfig: true, error: null);
    }
    if (result.errorMessage != null) {
      return (transaction: null, needsConfig: false, error: result.errorMessage);
    }

    final knownIds = sources.map((s) => s.id).toSet();
    final updated = ClassificationApplier.apply(
      tx: tx,
      result: result,
      categories: categories,
      knownSourceIds: knownIds,
      forceCategory: true,
      forceSource: true,
    );
    return (transaction: updated, needsConfig: false, error: null);
  }

  Future<ClassificationResult?> _classify(
    Transaction tx,
    List<Category> categories,
    List<PaymentSource> sources, {
    String? selectedCategoryId,
    String? userDescription,
  }) async {
    final ingest = await _db.getRawIngest(tx.rawIngestId);
    final body = ingest?['body'] as String? ?? '';
    final sender = ingest?['sender'] as String? ?? '';

    return _classifier.classify(
      transaction: tx,
      smsBody: body,
      smsSender: sender,
      categoryIds: categories.map((c) => c.id).toList(),
      selectedCategoryId: selectedCategoryId,
      userDescription: userDescription,
      subcategoryTaxonomy: subcategoryTaxonomyForLlm(),
      paymentSources: sources,
    );
  }
}
