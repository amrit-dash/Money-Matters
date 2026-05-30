import 'package:money_matters/models/category.dart';

/// Default spend categories for analytics and relabel UI.
///
/// Categories are **in-memory defaults only** — not persisted to Firestore.
/// Merchant matching rules live in code; user relabels sync to
/// `users/{uid}/transactions/{id}.categoryId`.
class CategoryService {
  CategoryService();

  static const defaultCategories = [
    Category(id: 'food', name: 'Food & Dining', system: true,
        merchantRules: ['SWIGGY', 'ZOMATO', 'ZEPTO', 'BLINKIT']),
    Category(id: 'transport', name: 'Transport', system: true,
        merchantRules: ['UBER', 'OLA', 'RAPIDO', 'METRO']),
    Category(id: 'shopping', name: 'Shopping', system: true,
        merchantRules: ['ZUDIO', 'AMAZON', 'FLIPKART', 'MYNTRA']),
    Category(id: 'bills', name: 'Bills & Utilities', system: true,
        merchantRules: ['AIRTEL', 'JIO', 'BESCOM', 'BILL']),
    Category(id: 'upi', name: 'UPI / Transfers', system: true,
        merchantRules: ['UPI', 'NEFT', 'IMPS']),
    Category(id: 'other', name: 'Other', system: false),
  ];

  Future<List<Category>> loadCategories() async => defaultCategories;

  Category? findById(String? id) {
    if (id == null) return null;
    for (final c in defaultCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Category uncategorized() =>
      const Category(id: 'uncategorized', name: 'Uncategorized', system: true);
}
