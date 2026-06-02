import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/transaction.dart';

import '../features/dashboard/local_dashboard_repository.dart';
import '../parse/llm_parser.dart';

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

    if (needsCategory) {
      final validCategory = result.categoryId != null &&
          categories.any((c) => c.id == result.categoryId);
      final categoryId =
          validCategory ? result.categoryId : updated.categoryId;
      final resolved = categoryId != null && !result.needsUserInput;

      updated = updated.copyWith(
        categoryId: categoryId,
        merchantNormalized:
            result.merchantNormalized ?? updated.merchantNormalized,
        needsClassification: resolved ? false : updated.needsClassification,
        ambiguous: resolved ? false : updated.ambiguous,
        classifiedBy: resolved ? ClassifiedBy.llm : updated.classifiedBy,
      );
    } else if (result.merchantNormalized != null) {
      updated = updated.copyWith(merchantNormalized: result.merchantNormalized);
    }

    if (result.userNotes != null && result.userNotes!.trim().isNotEmpty) {
      updated = updated.copyWith(userNotes: result.userNotes!.trim());
    }
    if (result.shoppingItems.isNotEmpty) {
      updated = updated.copyWith(shoppingItems: result.shoppingItems);
    }
    if (result.travelProvider != null && result.travelProvider!.isNotEmpty) {
      updated = updated.copyWith(travelProvider: result.travelProvider);
    }

    return updated;
  }
}

/// Form fields updated from an AI classify call (classify screen preview).
class AiClassifyFormUpdate {
  const AiClassifyFormUpdate({
    this.categoryId,
    this.paymentSourceId,
    this.merchantNormalized,
    this.userNotes,
    this.shoppingItems = const [],
    this.travelProvider,
    this.needsConfig = false,
    this.errorMessage,
  });

  final String? categoryId;
  final String? paymentSourceId;
  final String? merchantNormalized;
  final String? userNotes;
  final List<String> shoppingItems;
  final String? travelProvider;
  final bool needsConfig;
  final String? errorMessage;
}
