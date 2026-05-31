import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';

/// Aggregated spend for a time window, grouped by category.
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

/// Aggregated spend for a time window, grouped by payment source.
///
/// A null [source] means the spend did not match any saved bank/card and is
/// therefore excluded from headline totals (the "unmatched" bucket).
class SourceBreakdown {
  const SourceBreakdown({
    required this.source,
    required this.amount,
    required this.transactionCount,
  });

  final PaymentSource? source;
  final double amount;
  final int transactionCount;

  bool get isUnmatched => source == null;
  String get displayName => source?.name ?? 'Unmatched (not counted)';

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
    this.sources = const [],
    this.unmatchedSpend = 0,
    this.unmatchedCount = 0,
  });

  final String label;
  final DateTime start;
  final DateTime end;

  /// Total spend across **matched** sources only — unmatched is excluded.
  final double totalSpend;
  final double totalIncome;
  final List<CategoryBreakdown> breakdown;

  /// Per-payment-source spend (matched sources only).
  final List<SourceBreakdown> sources;

  /// Spend that matched no saved bank/card — surfaced but not counted.
  final double unmatchedSpend;
  final int unmatchedCount;

  double get net => totalIncome - totalSpend;
}

/// Read-only analytics contract for dashboard UI.
abstract class DashboardRepository {
  Future<PeriodSummary> weeklySummary({DateTime? anchor});
  Future<PeriodSummary> monthlySummary({DateTime? anchor});

  /// All transactions for a payment source (null = unmatched), newest first.
  Future<List<Transaction>> sourceTransactions(String? paymentSourceId);

  /// Resolves a payment source by id (for detail screens).
  Future<PaymentSource?> paymentSourceById(String id);

  /// Local SQLite counts for empty-state messaging.
  Future<({int rawIngests, int transactions})> localCounts();
}
