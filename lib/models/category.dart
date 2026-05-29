class Category {
  const Category({
    required this.id,
    required this.name,
    this.system = false,
    this.merchantRules = const [],
  });

  final String id;
  final String name;
  final bool system;
  final List<String> merchantRules;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'system': system,
        'merchantRules': merchantRules,
      };

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      system: json['system'] as bool? ?? false,
      merchantRules: (json['merchantRules'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  String? matchMerchant(String? merchant) {
    if (merchant == null || merchant.isEmpty) return null;
    final upper = merchant.toUpperCase();
    for (final rule in merchantRules) {
      if (upper.contains(rule.toUpperCase())) {
        return id;
      }
    }
    return null;
  }
}
