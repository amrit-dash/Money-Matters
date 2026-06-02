import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/parse/llm_parser.dart';

void main() {
  test('ClassificationResult.fromMap parses notes and shopping items', () {
    final result = ClassificationResult.fromMap({
      'categoryId': 'food',
      'merchantNormalized': 'Zepto',
      'needsUserInput': false,
      'userNotes': 'Weekly groceries',
      'shoppingItems': ['Milk', 'Bread'],
      'travelProvider': 'Uber',
    });

    expect(result.categoryId, 'food');
    expect(result.merchantNormalized, 'Zepto');
    expect(result.userNotes, 'Weekly groceries');
    expect(result.shoppingItems, ['Milk', 'Bread']);
    expect(result.travelProvider, 'Uber');
  });
}
