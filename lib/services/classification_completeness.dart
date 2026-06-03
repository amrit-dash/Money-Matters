import 'package:money_matters/models/transaction.dart';

import 'category_service.dart';

/// What the user still needs to finish classifying an inbox transaction.
class ClassificationMissingFields {
  const ClassificationMissingFields({required this.labels});

  final List<String> labels;

  bool get isEmpty => labels.isEmpty;
}

/// Whether a transaction can leave the inbox after classification.
bool isClassificationComplete(Transaction tx) {
  if (tx.categoryId == null || tx.categoryId!.isEmpty) return false;
  if (tx.unmatched && (tx.paymentSourceId == null || tx.paymentSourceId!.isEmpty)) {
    return false;
  }
  if (CategoryService.showTransferTo(
    transaction: tx,
    selectedCategoryId: tx.categoryId,
  )) {
    final to = tx.transferTo?.trim() ?? '';
    if (to.isEmpty) return false;
  }
  return true;
}

ClassificationMissingFields missingClassificationFields(Transaction tx) {
  final labels = <String>[];
  if (tx.categoryId == null || tx.categoryId!.isEmpty) {
    labels.add('Category');
  }
  if (tx.unmatched && (tx.paymentSourceId == null || tx.paymentSourceId!.isEmpty)) {
    labels.add('Bank or card');
  }
  if (CategoryService.showTransferTo(
    transaction: tx,
    selectedCategoryId: tx.categoryId,
  )) {
    final to = tx.transferTo?.trim() ?? '';
    if (to.isEmpty) labels.add('Transfer recipient');
  }
  if (CategoryService.showSubcategoryPicker(
    transaction: tx,
    selectedCategoryId: tx.categoryId,
  )) {
    if (tx.subcategoryId == null || tx.subcategoryId!.isEmpty) {
      labels.add('Subcategory or provider');
    }
  }
  return ClassificationMissingFields(labels: labels);
}
