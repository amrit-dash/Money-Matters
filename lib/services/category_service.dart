import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:money_matters/models/category.dart';

import '../core/auth/auth_service.dart';

/// Spend categories for analytics, relabel UI, and LLM classification.
///
/// Categories live in `users/{uid}/categories` and are seeded from
/// [defaultCategories] on first load. Falls back to in-memory defaults when
/// signed out or offline so the app never blocks on category availability.
class CategoryService {
  CategoryService({
    AuthService? authService,
    FirebaseFirestore? firestore,
  })  : _authService = authService,
        _firestore = firestore;

  final AuthService? _authService;
  final FirebaseFirestore? _firestore;

  List<Category>? _cache;

  static const defaultCategories = [
    Category(id: 'food', name: 'Food & Dining', system: true,
        merchantRules: ['SWIGGY', 'ZOMATO', 'ZEPTO', 'BLINKIT', 'EATFIT',
            'DOMINOS', 'STARBUCKS', 'INSTAMART']),
    Category(id: 'groceries', name: 'Groceries', system: true,
        merchantRules: ['BIGBASKET', 'DMART', 'RELIANCE FRESH', 'JIOMART',
            'MORE', 'SUPERMARKET']),
    Category(id: 'transport', name: 'Transport', system: true,
        merchantRules: ['UBER', 'OLA', 'RAPIDO', 'METRO', 'IRCTC', 'REDBUS',
            'FUEL', 'PETROL', 'HPCL', 'IOCL', 'BPCL']),
    Category(id: 'shopping', name: 'Shopping', system: true,
        merchantRules: ['ZUDIO', 'AMAZON', 'FLIPKART', 'MYNTRA', 'AJIO',
            'NYKAA', 'MEESHO', 'DECATHLON']),
    Category(id: 'bills', name: 'Bills & Utilities', system: true,
        merchantRules: ['AIRTEL', 'JIO', 'VI', 'BESCOM', 'BILL', 'RECHARGE',
            'ELECTRICITY', 'BROADBAND', 'GAS']),
    Category(id: 'entertainment', name: 'Entertainment', system: true,
        merchantRules: ['NETFLIX', 'SPOTIFY', 'HOTSTAR', 'PRIME VIDEO',
            'BOOKMYSHOW', 'PVR', 'YOUTUBE']),
    Category(id: 'health', name: 'Health', system: true,
        merchantRules: ['PHARMEASY', 'APOLLO', 'NETMEDS', '1MG', 'PHARMACY',
            'HOSPITAL', 'CLINIC', 'CULT']),
    Category(id: 'transfer', name: 'Transfers', system: true,
        merchantRules: ['UPI', 'NEFT', 'IMPS', 'RTGS']),
    Category(id: 'other', name: 'Other', system: false),
  ];

  CollectionReference<Map<String, dynamic>>? _collection() {
    final auth = _authService;
    final fs = _firestore;
    if (auth == null || fs == null || !auth.isSignedIn) return null;
    return fs.collection('users').doc(auth.requireUid()).collection('categories');
  }

  Future<List<Category>> loadCategories() async {
    if (_cache != null) return _cache!;

    final col = _collection();
    if (col == null) return defaultCategories;

    try {
      final snapshot = await col.get();
      if (snapshot.docs.isEmpty) {
        await _seedDefaults(col);
        _cache = List<Category>.from(defaultCategories);
        return _cache!;
      }
      _cache = snapshot.docs.map(_fromDoc).toList();
      return _cache!;
    } catch (e) {
      debugPrint('CategoryService.loadCategories: $e — using defaults');
      return defaultCategories;
    }
  }

  Future<void> _seedDefaults(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    final batch = (_firestore!).batch();
    for (final c in defaultCategories) {
      batch.set(col.doc(c.id), {
        'name': c.name,
        'system': c.system,
        'merchantRules': c.merchantRules,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    debugPrint('CategoryService: seeded ${defaultCategories.length} categories');
  }

  /// Teaches a user-specific merchant rule so future parses auto-categorize.
  Future<void> addMerchantRule({
    required String categoryId,
    required String merchant,
  }) async {
    final col = _collection();
    final rule = merchant.trim().toUpperCase();
    if (col == null || rule.isEmpty) return;
    try {
      await col.doc(categoryId).set({
        'merchantRules': FieldValue.arrayUnion([rule]),
      }, SetOptions(merge: true));
      _cache = null;
    } catch (e) {
      debugPrint('CategoryService.addMerchantRule: $e');
    }
  }

  /// Forces a reload on next [loadCategories].
  void invalidateCache() => _cache = null;

  Category _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Category(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      system: data['system'] as bool? ?? false,
      merchantRules: (data['merchantRules'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Category? findById(String? id) {
    if (id == null) return null;
    final source = _cache ?? defaultCategories;
    for (final c in source) {
      if (c.id == id) return c;
    }
    for (final c in defaultCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Category uncategorized() =>
      const Category(id: 'uncategorized', name: 'Uncategorized', system: true);
}
