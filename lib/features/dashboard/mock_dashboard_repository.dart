import 'package:intl/intl.dart';

import 'package:money_matters/models/category.dart';

import 'dashboard_repository.dart';

/// Mock data until coordinator wires SQLite / Firestore.
class MockDashboardRepository implements DashboardRepository {
  MockDashboardRepository();

  static final _categories = [
    Category(id: 'food', name: 'Food & Dining', system: true),
    Category(id: 'transport', name: 'Transport', system: true),
    Category(id: 'shopping', name: 'Shopping', system: true),
    Category(id: 'bills', name: 'Bills & Utilities', system: true),
    Category(id: 'upi', name: 'UPI / Transfers', system: true),
  ];

  @override
  Future<PeriodSummary> weeklySummary({DateTime? anchor}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final end = anchor ?? DateTime.now();
    final start = end.subtract(const Duration(days: 6));
    return PeriodSummary(
      label: 'Week of ${DateFormat('d MMM').format(start)}',
      start: start,
      end: end,
      totalSpend: 12450,
      totalIncome: 0,
      breakdown: [
        CategoryBreakdown(
          category: _categories[0],
          amount: 4200,
          transactionCount: 8,
        ),
        CategoryBreakdown(
          category: _categories[1],
          amount: 1800,
          transactionCount: 4,
        ),
        CategoryBreakdown(
          category: _categories[2],
          amount: 3500,
          transactionCount: 3,
        ),
        CategoryBreakdown(
          category: _categories[3],
          amount: 1950,
          transactionCount: 2,
        ),
        CategoryBreakdown(
          category: _categories[4],
          amount: 1000,
          transactionCount: 5,
        ),
      ],
    );
  }

  @override
  Future<PeriodSummary> monthlySummary({DateTime? anchor}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final ref = anchor ?? DateTime.now();
    final start = DateTime(ref.year, ref.month);
    final end = DateTime(ref.year, ref.month + 1, 0);
    return PeriodSummary(
      label: DateFormat('MMMM yyyy').format(start),
      start: start,
      end: end,
      totalSpend: 48200,
      totalIncome: 85000,
      breakdown: [
        CategoryBreakdown(
          category: _categories[0],
          amount: 14200,
          transactionCount: 28,
        ),
        CategoryBreakdown(
          category: _categories[1],
          amount: 6800,
          transactionCount: 12,
        ),
        CategoryBreakdown(
          category: _categories[2],
          amount: 11500,
          transactionCount: 9,
        ),
        CategoryBreakdown(
          category: _categories[3],
          amount: 9200,
          transactionCount: 6,
        ),
        CategoryBreakdown(
          category: _categories[4],
          amount: 6500,
          transactionCount: 18,
        ),
      ],
    );
  }
}
