import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/models/transaction.dart';
import 'package:money_matters/services/category_service.dart';

void main() {
  group('CategoryService.defaultCategories', () {
    test('includes expanded system categories', () {
      final ids = CategoryService.defaultCategories.map((c) => c.id).toSet();
      expect(ids, containsAll([
        'groceries',
        'food',
        'savings',
        'income',
        'subscriptions',
        'travel',
        'education',
        'fees',
        'transfer',
        'bills',
        'other',
      ]));
    });

    test('lists groceries before food to avoid food-first UI bias', () {
      final ids = CategoryService.defaultCategories.map((c) => c.id).toList();
      expect(ids.indexOf('groceries'), lessThan(ids.indexOf('food')));
      expect(ids.last, 'other');
    });

    test('transport is Rides & Commute without train booking merchants', () {
      final transport = CategoryService.defaultCategories
          .firstWhere((c) => c.id == 'transport');
      final travel = CategoryService.defaultCategories
          .firstWhere((c) => c.id == 'travel');

      expect(transport.name, 'Rides & Commute');
      expect(transport.matchMerchant('UBER'), 'transport');
      expect(transport.matchMerchant('IRCTC'), isNull);
      expect(travel.matchMerchant('IRCTC'), 'travel');
      expect(travel.matchMerchant('REDBUS'), 'travel');
    });

    test('bills, food, and groceries expose subcategories', () {
      expect(
        CategoryService.subcategoriesFor('bills').map((s) => s.id),
        containsAll(['internet', 'rent', 'electricity', 'water', 'phone', 'dth']),
      );
      expect(
        CategoryService.subcategoriesFor('food').map((s) => s.id),
        containsAll(['delivery', 'dine_in']),
      );
      expect(
        CategoryService.subcategoriesFor('groceries').map((s) => s.id),
        containsAll(['supermarket', 'quick_commerce']),
      );
    });

    test('quick-commerce merchants map to groceries not food', () {
      final groceries = CategoryService.defaultCategories
          .firstWhere((c) => c.id == 'groceries');
      final food = CategoryService.defaultCategories
          .firstWhere((c) => c.id == 'food');

      expect(groceries.matchMerchant('ZEPTO'), 'groceries');
      expect(groceries.matchMerchant('BLINKIT'), 'groceries');
      expect(groceries.matchMerchant('INSTAMART'), 'groceries');
      expect(food.matchMerchant('SWIGGY'), 'food');
      expect(food.matchMerchant('ZEPTO'), isNull);
    });
  });

  group('CategoryService.showShoppingList', () {
    Transaction tx({
      String? categoryId,
      String? paymentSourceId,
      bool unmatched = false,
      ClassifiedBy? classifiedBy,
    }) {
      return Transaction(
        id: 't1',
        rawIngestId: 'r1',
        amount: 100,
        timestamp: DateTime.parse('2026-05-29T00:00:00+05:30'),
        type: TransactionType.debit,
        categoryId: categoryId,
        paymentSourceId: paymentSourceId,
        unmatched: unmatched,
        classifiedBy: classifiedBy,
      );
    }

    test('hidden without matched payment source', () {
      expect(
        CategoryService.showShoppingList(
          transaction: tx(categoryId: 'groceries'),
          selectedCategoryId: 'groceries',
        ),
        isFalse,
      );
    });

    test('hidden for unmatched account even with shopping category', () {
      expect(
        CategoryService.showShoppingList(
          transaction: tx(
            categoryId: 'shopping',
            paymentSourceId: 'card-1',
            unmatched: true,
          ),
          selectedCategoryId: 'shopping',
        ),
        isFalse,
      );
    });

    test('hidden for food/dining and unset categories', () {
      final matched = tx(categoryId: 'food', paymentSourceId: 'card-1');
      expect(
        CategoryService.showShoppingList(transaction: matched),
        isFalse,
      );
      expect(
        CategoryService.showShoppingList(
          transaction: tx(paymentSourceId: 'card-1'),
        ),
        isFalse,
      );
    });

    test('shown for groceries/shopping with matched payment', () {
      final base = tx(paymentSourceId: 'card-1');
      expect(
        CategoryService.showShoppingList(
          transaction: base,
          selectedCategoryId: 'groceries',
        ),
        isTrue,
      );
      expect(
        CategoryService.showShoppingList(
          transaction: base.copyWith(
            categoryId: 'shopping',
            classifiedBy: ClassifiedBy.llm,
          ),
        ),
        isTrue,
      );
    });
  });

  group('CategoryService.showTravelProvider', () {
    Transaction tx({
      String? categoryId,
      String? paymentSourceId,
      bool unmatched = false,
    }) {
      return Transaction(
        id: 't1',
        rawIngestId: 'r1',
        amount: 100,
        timestamp: DateTime.parse('2026-05-29T00:00:00+05:30'),
        type: TransactionType.debit,
        categoryId: categoryId,
        paymentSourceId: paymentSourceId,
        unmatched: unmatched,
      );
    }

    test('hidden without matched payment source', () {
      expect(
        CategoryService.showTravelProvider(
          transaction: tx(categoryId: 'travel'),
          selectedCategoryId: 'travel',
        ),
        isFalse,
      );
    });

    test('hidden for groceries and unset categories', () {
      expect(
        CategoryService.showTravelProvider(
          transaction: tx(categoryId: 'groceries', paymentSourceId: 'card-1'),
        ),
        isFalse,
      );
      expect(
        CategoryService.showTravelProvider(
          transaction: tx(paymentSourceId: 'card-1'),
          selectedCategoryId: 'food',
        ),
        isFalse,
      );
    });

    test('shown for travel/transport with matched payment', () {
      final base = tx(paymentSourceId: 'card-1');
      expect(
        CategoryService.showTravelProvider(
          transaction: base,
          selectedCategoryId: 'travel',
        ),
        isTrue,
      );
      expect(
        CategoryService.showTravelProvider(
          transaction: base.copyWith(categoryId: 'transport'),
        ),
        isTrue,
      );
    });
  });
}
