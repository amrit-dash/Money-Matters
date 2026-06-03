import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/category_taxonomy.dart';
import 'package:money_matters/models/transaction.dart';

import '../features/dashboard/local_dashboard_repository.dart';
import '../parse/llm_parser.dart';
import 'category_service.dart';

/// Applies [ClassificationResult] from Gemini to a transaction (pipeline + UI).
class ClassificationApplier {
  const ClassificationApplier._();

  static Transaction apply({
    required Transaction tx,
    required ClassificationResult result,
    required List<Category> categories,
    required Set<String> knownSourceIds,
    bool forceCategory = false,
    bool forceSource = false,
    String? selectedCategoryId,
    bool allowLlmNotes = false,
  }) {
    final needsCategory =
        forceCategory || tx.needsClassification || tx.ambiguous;
    final needsSource = forceSource ||
        (LocalDashboardRepository.isUnmatched(tx, knownSourceIds) &&
            knownSourceIds.isNotEmpty);

    var updated = tx;

    if (needsSource &&
        result.paymentSourceId != null &&
        knownSourceIds.contains(result.paymentSourceId) &&
        (result.paymentSourceConfidence ?? 0) >=
            ClassificationResult.paymentSourceConfidenceThreshold) {
      updated = updated.copyWith(
        paymentSourceId: result.paymentSourceId,
        unmatched: false,
      );
    }

    final displayName = result.merchantNormalized;
    if (displayName != null && displayName.isNotEmpty) {
      updated = updated.copyWith(
        merchantNormalized: displayName,
        merchant: _shouldReplaceMerchant(updated.merchant)
            ? displayName
            : updated.merchant,
      );
    }

    if (needsCategory) {
      final validCategory = result.categoryId != null &&
          categories.any((c) => c.id == result.categoryId);
      var categoryId =
          validCategory ? result.categoryId : updated.categoryId;

      if (selectedCategoryId != null &&
          categories.any((c) => c.id == selectedCategoryId)) {
        categoryId = selectedCategoryId;
      }

      final confidence = result.categoryConfidence ??
          (result.needsUserInput ? 0.0 : 1.0);
      final canAutoApplyCategory = categoryId != null &&
          !result.needsUserInput &&
          confidence >= ClassificationResult.categoryConfidenceThreshold;

      updated = updated.copyWith(
        categoryId: canAutoApplyCategory ? categoryId : updated.categoryId,
        needsClassification:
            canAutoApplyCategory ? false : true,
        ambiguous: canAutoApplyCategory ? false : updated.ambiguous,
        classifiedBy:
            canAutoApplyCategory ? ClassifiedBy.llm : updated.classifiedBy,
      );
    }

    final effectiveCategoryId = updated.categoryId;
    if (result.subcategoryId != null &&
        isValidSubcategory(effectiveCategoryId, result.subcategoryId)) {
      updated = updated.copyWith(subcategoryId: result.subcategoryId);
    }

    // Pipeline must not auto-set notes; only user-confirmed NL classify may.
    if (allowLlmNotes &&
        result.userNotes != null &&
        result.userNotes!.trim().isNotEmpty &&
        !_isGenericPaidToNote(result.userNotes!, displayName)) {
      updated = updated.copyWith(userNotes: result.userNotes!.trim());
    }
    if (result.shoppingItems.isNotEmpty) {
      updated = updated.copyWith(shoppingItems: result.shoppingItems);
    }
    if (result.travelProvider != null && result.travelProvider!.isNotEmpty) {
      updated = updated.copyWith(travelProvider: result.travelProvider);
    }

    final transferTo = result.transferTo ??
        (updated.categoryId == CategoryService.transferCategoryId
            ? displayName
            : null);
    if (transferTo != null && transferTo.isNotEmpty) {
      updated = updated.copyWith(transferTo: transferTo);
    }

    return updated;
  }

  /// Replace raw VPA / long opaque merchant strings with the LLM display name.
  static bool _shouldReplaceMerchant(String? merchant) {
    if (merchant == null || merchant.isEmpty) return true;
    if (merchant.contains('@')) return true;
    if (merchant.length > 48) return true;
    // UPI payment-type codes (P2A, P2M) and numeric reference fragments.
    if (RegExp(r'^[A-Z0-9]{2,4}$').hasMatch(merchant)) return true;
    if (RegExp(r'^\d+$').hasMatch(merchant)) return true;
    return false;
  }

  /// LLM sometimes echoes the payee as a note — skip unless user wrote it.
  static bool _isGenericPaidToNote(String note, String? merchantNormalized) {
    final trimmed = note.trim();
    if (RegExp(r'^paid to .+$', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }
    if (merchantNormalized != null &&
        merchantNormalized.isNotEmpty &&
        trimmed.toLowerCase() ==
            'paid to ${merchantNormalized.toLowerCase()}') {
      return true;
    }
    return false;
  }
}

/// Form fields updated from an AI classify call (classify screen preview).
class AiClassifyFormUpdate {
  const AiClassifyFormUpdate({
    this.categoryId,
    this.paymentSourceId,
    this.merchantNormalized,
    this.merchant,
    this.subcategoryId,
    this.userNotes,
    this.shoppingItems = const [],
    this.travelProvider,
    this.transferTo,
    this.suggestedCategoryId,
    this.suggestedCategoryName,
    this.needsConfig = false,
    this.needsUserInput = false,
    this.errorMessage,
  });

  final String? categoryId;
  final String? paymentSourceId;
  final String? merchantNormalized;
  /// Corrected raw merchant (when AI replaces opaque parse like P2A).
  final String? merchant;
  final String? subcategoryId;
  final String? userNotes;
  final List<String> shoppingItems;
  final String? travelProvider;
  final String? transferTo;
  final String? suggestedCategoryId;
  final String? suggestedCategoryName;
  final bool needsConfig;
  final bool needsUserInput;
  final String? errorMessage;
}
