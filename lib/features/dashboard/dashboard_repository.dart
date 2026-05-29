import 'package:money_matters/models/category.dart';

/// Aggregated spend for a time window.
class CategoryBreakdown {
  const CategoryBreakdown({
    required this.category,
    required this.amount,
    required this.transactionCount,
  });

  final Category category;
  final double amount;
  final int transactionCount;

  double shareOf(double total) => total <= 0 ? 0 : amount / total;
}

/// Weekly or monthly dashboard summary.
class PeriodSummary {
  const PeriodSummary({
    required this.label,
    required this.start,
    required this.end,
    required this.totalSpend,
    required this.totalIncome,
    required this.breakdown,
  });

  final String label;
  final DateTime start;
  final DateTime end;
  final double totalSpend;
  final double totalIncome;
  final List<CategoryBreakdown> breakdown;

  double get net => totalIncome - totalSpend;
}

/// Read-only analytics contract for dashboard UI.
abstract class DashboardRepository {
  Future<PeriodSummary> weeklySummary({DateTime? anchor});
  Future<PeriodSummary> monthlySummary({DateTime? anchor});
}
