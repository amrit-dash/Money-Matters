import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/transaction.dart';
import 'package:money_matters/parse/llm_parser.dart';
import 'package:money_matters/services/classification_applier.dart';

void main() {
  test('ClassificationResult.fromMap parses extended LLM fields', () {
    final result = ClassificationResult.fromMap({
      'categoryId': 'bills',
      'merchantNormalized': 'Nizam M',
      'subcategoryId': 'electricity',
      'needsUserInput': false,
      'userNotes': 'Monthly bill',
      'shoppingItems': ['Milk'],
      'travelProvider': 'Uber',
      'transferTo': 'John',
      'suggestedCategoryId': 'pet_care',
      'suggestedCategoryName': 'Pet Care',
    });

    expect(result.categoryId, 'bills');
    expect(result.merchantNormalized, 'Nizam M');
    expect(result.subcategoryId, 'electricity');
    expect(result.transferTo, 'John');
    expect(result.suggestedCategoryId, 'pet_care');
  });

  test('ClassificationApplier updates merchant for VPA strings', () {
    final tx = Transaction(
      id: '1',
      rawIngestId: 'ingest',
      amount: 500,
      timestamp: DateTime.parse('2026-05-29T00:00:00+05:30'),
      type: TransactionType.debit,
      merchant: 'nizam@ybl',
    );
    // ignore: invalid_use_of_visible_for_testing_member
    const categories = [Category(id: 'transfer', name: 'Transfers')];
    const result = ClassificationResult(
      categoryId: 'transfer',
      merchantNormalized: 'Nizam M',
      transferTo: 'Nizam M',
      needsUserInput: false,
    );

    final updated = ClassificationApplier.apply(
      tx: tx,
      result: result,
      categories: categories,
      knownSourceIds: {},
      forceCategory: true,
    );

    expect(updated.merchant, 'Nizam M');
    expect(updated.merchantNormalized, 'Nizam M');
    expect(updated.transferTo, 'Nizam M');
    expect(updated.categoryId, 'transfer');
  });

  test('ClassificationApplier respects selectedCategoryId', () {
    final tx = Transaction(
      id: '1',
      rawIngestId: 'ingest',
      amount: 500,
      timestamp: DateTime.parse('2026-05-29T00:00:00+05:30'),
      type: TransactionType.debit,
      needsClassification: true,
    );
    const categories = [
      Category(id: 'food', name: 'Food'),
      Category(id: 'transfer', name: 'Transfers'),
    ];
    const result = ClassificationResult(
      categoryId: 'food',
      merchantNormalized: 'Nizam M',
      needsUserInput: false,
    );

    final updated = ClassificationApplier.apply(
      tx: tx,
      result: result,
      categories: categories,
      knownSourceIds: {},
      forceCategory: true,
      selectedCategoryId: 'transfer',
    );

    expect(updated.categoryId, 'transfer');
  });
}
