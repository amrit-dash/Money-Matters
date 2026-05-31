import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/transaction.dart';

import '../core/auth/auth_service.dart';

/// Spend categories for analytics, relabel UI, and LLM classification.
///
/// Categories live in `users/{uid}/categories` and are seeded from
/// [defaultCategories] on first load. Missing system categories are merged on
/// later loads so upgrades add Savings, Subscriptions, etc. without wiping
/// user edits. Falls back to in-memory defaults when signed out or offline.
class CategoryService {
  CategoryService({
    AuthService? authService,
    FirebaseFirestore? firestore,
  })  : _authService = authService,
        _firestore = firestore;

  final AuthService? _authService;
  final FirebaseFirestore? _firestore;

  List<Category>? _cache;

  /// Category ids where the classify flow may capture a per-item shopping list.
  static const shoppingCategoryIds = {'groceries', 'shopping'};

  static const defaultCategories = [
    Category(
      id: 'groceries',
      name: 'Groceries',
      system: true,
      merchantRules: [
        'BIGBASKET',
        'DMART',
        'RELIANCE FRESH',
        'JIOMART',
        'MORE',
        'SUPERMARKET',
        'ZEPTO',
        'BLINKIT',
        'INSTAMART',
      ],
    ),
    Category(
      id: 'food',
      name: 'Food & Dining',
      system: true,
      merchantRules: [
        'SWIGGY',
        'ZOMATO',
        'EATFIT',
        'DOMINOS',
        'STARBUCKS',
      ],
    ),
    Category(
      id: 'transport',
      name: 'Transport',
      system: true,
      merchantRules: [
        'UBER',
        'OLA',
        'RAPIDO',
        'METRO',
        'IRCTC',
        'REDBUS',
        'FUEL',
        'PETROL',
        'HPCL',
        'IOCL',
        'BPCL',
      ],
    ),
    Category(
      id: 'shopping',
      name: 'Shopping',
      system: true,
      merchantRules: [
        'ZUDIO',
        'AMAZON',
        'FLIPKART',
        'MYNTRA',
        'AJIO',
        'NYKAA',
        'MEESHO',
        'DECATHLON',
      ],
    ),
    Category(
      id: 'bills',
      name: 'Bills & Utilities',
      system: true,
      merchantRules: [
        'AIRTEL',
        'JIO',
        'VI',
        'BESCOM',
        'BILL',
        'RECHARGE',
        'ELECTRICITY',
        'BROADBAND',
        'GAS',
      ],
    ),
    Category(
      id: 'subscriptions',
      name: 'Subscriptions',
      system: true,
      merchantRules: [
        'NETFLIX',
        'SPOTIFY',
        'HOTSTAR',
        'PRIME VIDEO',
        'YOUTUBE',
        'APPLE',
        'GOOGLE ONE',
      ],
    ),
    Category(
      id: 'entertainment',
      name: 'Entertainment',
      system: true,
      merchantRules: ['BOOKMYSHOW', 'PVR', 'INOX', 'CULTFIT'],
    ),
    Category(
      id: 'health',
      name: 'Health & Fitness',
      system: true,
      merchantRules: [
        'PHARMEASY',
        'APOLLO',
        'NETMEDS',
        '1MG',
        'PHARMACY',
        'HOSPITAL',
        'CLINIC',
        'CULT',
      ],
    ),
    Category(
      id: 'travel',
      name: 'Travel',
      system: true,
      merchantRules: [
        'MAKEMYTRIP',
        'GOIBIBO',
        'INDIGO',
        'AIR INDIA',
        'SPICEJET',
        'OYO',
      ],
    ),
    Category(
      id: 'education',
      name: 'Education',
      system: true,
      merchantRules: ['BYJU', 'UDEMY', 'COURSERA', 'UNACADEMY'],
    ),
    Category(
      id: 'savings',
      name: 'Savings & Investments',
      system: true,
      merchantRules: [
        'ZERODHA',
        'GROWW',
        'COIN',
        'MUTUAL FUND',
        'SIP',
        'NPS',
        'PPF',
      ],
    ),
    Category(
      id: 'income',
      name: 'Income',
      system: true,
      merchantRules: ['SALARY', 'CREDITED BY', 'NEFT CR', 'IMPS CR'],
    ),
    Category(
      id: 'transfer',
      name: 'Transfers',
      system: true,
      merchantRules: ['UPI', 'NEFT', 'IMPS', 'RTGS'],
    ),
    Category(
      id: 'fees',
      name: 'Fees & Charges',
      system: true,
      merchantRules: [
        'ANNUAL FEE',
        'LATE FEE',
        'INTEREST CHARGED',
        'PROCESSING FEE',
      ],
    ),
    Category(
      id: 'gifts',
      name: 'Gifts & Donations',
      system: true,
      merchantRules: ['DONATION', 'CHARITY', 'KETTO'],
    ),
    Category(
      id: 'personal',
      name: 'Personal Care',
      system: true,
      merchantRules: ['SALON', 'SPA', 'GROOMING'],
    ),
    Category(id: 'other', name: 'Other', system: false),
  ];

  /// Shopping list UI: matched payment + groceries/shopping category only.
  static bool showShoppingList({
    required Transaction transaction,
    String? selectedCategoryId,
  }) {
    if (transaction.unmatched || transaction.paymentSourceId == null) {
      return false;
    }
    final categoryId = selectedCategoryId ?? transaction.categoryId;
    if (categoryId == null) return false;
    return shoppingCategoryIds.contains(categoryId);
  }

  CollectionReference<Map<String, dynamic>>? _collection() {
    final auth = _authService;
    final fs = _firestore;
    if (auth == null || fs == null || !auth.isSignedIn) return null;
    return fs.collection('users').doc(auth.requireUid()).collection('categories');
  }

  Future<List<Category>> loadCategories() async {
    if (_cache != null) return _cache!;

    final col = _collection();
    if (col == null) return _sorted(defaultCategories);

    try {
      final snapshot = await col.get();
      if (snapshot.docs.isEmpty) {
        await _seedDefaults(col);
        _cache = _sorted(List<Category>.from(defaultCategories));
        return _cache!;
      }
      final loaded = snapshot.docs.map(_fromDoc).toList();
      await _mergeMissingSystemCategories(col, loaded);
      _cache = _sorted(loaded);
      return _cache!;
    } catch (e) {
      debugPrint('CategoryService.loadCategories: $e — using defaults');
      return _sorted(defaultCategories);
    }
  }

  List<Category> _sorted(List<Category> categories) {
    int orderFor(String id) {
      final idx = defaultCategories.indexWhere((c) => c.id == id);
      return idx >= 0 ? idx : defaultCategories.length;
    }

    final copy = List<Category>.from(categories)
      ..sort((a, b) => orderFor(a.id).compareTo(orderFor(b.id)));
    return copy;
  }

  Future<void> _seedDefaults(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    final batch = (_firestore!).batch();
    for (final c in defaultCategories) {
      batch.set(col.doc(c.id), _categoryDoc(c));
    }
    await batch.commit();
    debugPrint('CategoryService: seeded ${defaultCategories.length} categories');
  }

  /// Adds system categories introduced in app upgrades without overwriting
  /// existing docs (preserves user merchant rules and renames).
  Future<void> _mergeMissingSystemCategories(
    CollectionReference<Map<String, dynamic>> col,
    List<Category> existing,
  ) async {
    final existingIds = existing.map((c) => c.id).toSet();
    final missing =
        defaultCategories.where((c) => c.system && !existingIds.contains(c.id));
    if (missing.isEmpty) return;

    final batch = (_firestore!).batch();
    for (final c in missing) {
      batch.set(col.doc(c.id), _categoryDoc(c));
      existing.add(c);
    }
    await batch.commit();
    debugPrint(
      'CategoryService: merged ${missing.length} new system categories',
    );
  }

  Map<String, dynamic> _categoryDoc(Category c) => {
        'name': c.name,
        'system': c.system,
        'merchantRules': c.merchantRules,
        'createdAt': FieldValue.serverTimestamp(),
      };

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
