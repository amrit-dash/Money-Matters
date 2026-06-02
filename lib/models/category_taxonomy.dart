/// Optional sub-labels under a top-level spend category.
///
/// Stored on [Transaction.subcategoryId] (slug, e.g. `rent`, `delivery`).
/// Separate from [Transaction.travelProvider] (app name chips on transport/travel)
/// and [Transaction.shoppingItems] (free-text item list on groceries/shopping).
/// See [categorySubcategories] and [docs/category-taxonomy.md].
class CategorySubcategory {
  const CategorySubcategory({required this.id, required this.label});

  final String id;
  final String label;
}

/// Subcategory chips shown in classify UI, keyed by parent category id.
const Map<String, List<CategorySubcategory>> categorySubcategories = {
  'groceries': [
    CategorySubcategory(id: 'supermarket', label: 'Supermarket'),
    CategorySubcategory(id: 'quick_commerce', label: 'Quick delivery'),
  ],
  'bills': [
    CategorySubcategory(id: 'internet', label: 'Internet & Broadband'),
    CategorySubcategory(id: 'rent', label: 'Rent'),
    CategorySubcategory(id: 'electricity', label: 'Electricity'),
    CategorySubcategory(id: 'water', label: 'Water'),
    CategorySubcategory(id: 'phone', label: 'Phone & Mobile'),
    CategorySubcategory(id: 'dth', label: 'DTH & Cable'),
    CategorySubcategory(id: 'gas', label: 'Gas'),
    CategorySubcategory(id: 'other', label: 'Other bill'),
  ],
  'food': [
    CategorySubcategory(id: 'delivery', label: 'Delivery'),
    CategorySubcategory(id: 'dine_in', label: 'Dine-in'),
    CategorySubcategory(id: 'takeaway', label: 'Takeaway / Pickup'),
    CategorySubcategory(id: 'cafe', label: 'Café & Snacks'),
  ],
  'transport': [
    CategorySubcategory(id: 'ride_hail', label: 'Ride-hailing'),
    CategorySubcategory(id: 'transit', label: 'Metro / Bus'),
    CategorySubcategory(id: 'fuel', label: 'Fuel'),
    CategorySubcategory(id: 'parking', label: 'Parking & Toll'),
  ],
  'travel': [
    CategorySubcategory(id: 'flight', label: 'Flight'),
    CategorySubcategory(id: 'hotel', label: 'Hotel & Stay'),
    CategorySubcategory(id: 'train', label: 'Train / Bus ticket'),
    CategorySubcategory(id: 'package', label: 'Holiday package'),
  ],
};

List<CategorySubcategory> subcategoriesForCategory(String? categoryId) {
  if (categoryId == null || categoryId.isEmpty) return const [];
  return categorySubcategories[categoryId] ?? const [];
}

bool categoryHasSubcategories(String? categoryId) =>
    subcategoriesForCategory(categoryId).isNotEmpty;

String? subcategoryLabel(String? categoryId, String? subcategoryId) {
  if (categoryId == null || subcategoryId == null) return null;
  for (final sub in subcategoriesForCategory(categoryId)) {
    if (sub.id == subcategoryId) return sub.label;
  }
  return null;
}

bool isValidSubcategory(String? categoryId, String? subcategoryId) {
  if (subcategoryId == null || subcategoryId.isEmpty) return true;
  if (categoryId == null) return false;
  return subcategoriesForCategory(categoryId)
      .any((s) => s.id == subcategoryId);
}

/// Subcategory ids keyed by parent category — sent to the classify Cloud Function.
Map<String, List<String>> subcategoryTaxonomyForLlm() {
  return {
    for (final entry in categorySubcategories.entries)
      entry.key: entry.value.map((s) => s.id).toList(),
  };
}
