import 'package:flutter/material.dart';

/// Maps category / subcategory slugs to Material icons for lists and detail headers.
IconData categoryIconFor({
  String? categoryId,
  String? subcategoryId,
}) {
  if (subcategoryId != null && subcategoryId.isNotEmpty) {
    final sub = _subcategoryIcons[subcategoryId];
    if (sub != null) return sub;
  }
  if (categoryId != null && categoryId.isNotEmpty) {
    return _categoryIcons[categoryId] ?? Icons.category_outlined;
  }
  return Icons.receipt_long_outlined;
}

const Map<String, IconData> _categoryIcons = {
  'groceries': Icons.local_grocery_store_outlined,
  'food': Icons.restaurant_outlined,
  'transport': Icons.directions_car_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'bills': Icons.receipt_long_outlined,
  'subscriptions': Icons.subscriptions_outlined,
  'entertainment': Icons.movie_outlined,
  'health': Icons.medical_services_outlined,
  'travel': Icons.flight_outlined,
  'education': Icons.school_outlined,
  'savings': Icons.savings_outlined,
  'income': Icons.payments_outlined,
  'transfer': Icons.swap_horiz_outlined,
  'fees': Icons.account_balance_outlined,
  'gifts': Icons.card_giftcard_outlined,
  'personal': Icons.spa_outlined,
  'other': Icons.more_horiz_outlined,
};

const Map<String, IconData> _subcategoryIcons = {
  'supermarket': Icons.store_outlined,
  'quick_commerce': Icons.delivery_dining_outlined,
  'internet': Icons.wifi_outlined,
  'rent': Icons.home_outlined,
  'electricity': Icons.bolt_outlined,
  'water': Icons.water_drop_outlined,
  'phone': Icons.phone_android_outlined,
  'dth': Icons.live_tv_outlined,
  'gas': Icons.local_fire_department_outlined,
  'other': Icons.receipt_outlined,
  'delivery': Icons.delivery_dining_outlined,
  'dine_in': Icons.restaurant_outlined,
  'takeaway': Icons.takeout_dining_outlined,
  'cafe': Icons.local_cafe_outlined,
  'ride_hail': Icons.local_taxi_outlined,
  'transit': Icons.directions_bus_outlined,
  'fuel': Icons.local_gas_station_outlined,
  'parking': Icons.local_parking_outlined,
  'flight': Icons.flight_outlined,
  'hotel': Icons.hotel_outlined,
  'train': Icons.train_outlined,
  'package': Icons.card_travel_outlined,
  'online': Icons.shopping_cart_outlined,
  'offline': Icons.storefront_outlined,
  'maintenance': Icons.handyman_outlined,
};

/// Icon for [ClassifiedBy] tags (rules / user / LLM).
IconData classifiedByIcon(String classifiedByName) {
  return switch (classifiedByName) {
    'llm' => Icons.auto_awesome_outlined,
    'user' => Icons.person_outline,
    'rules' => Icons.rule_outlined,
    _ => Icons.label_outline,
  };
}
