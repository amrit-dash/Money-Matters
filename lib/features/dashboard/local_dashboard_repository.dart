import 'package:intl/intl.dart';
import 'package:money_matters/models/transaction.dart';

import '../../core/db/local_database.dart';
import '../../services/category_service.dart';
import 'dashboard_repository.dart';

/// Dashboard analytics from local SQLite transactions.
class LocalDashboardRepository implements DashboardRepository {
  LocalDashboardRepository({
    required LocalDatabase localDatabase,
    required CategoryService categoryService,
  })  : _db = localDatabase,
        _categories = categoryService;

  final LocalDatabase _db;
  final CategoryService _categories;

  @override
  Future<PeriodSummary> weeklySummary({DateTime? anchor}) async {
    final end = _endOfDay(anchor ?? DateTime.now());
    final startDay = end.subtract(const Duration(days: 6));
    final rangeStart = DateTime(startDay.year, startDay.month, startDay.day);
    return _buildSummary(
      label: 'Week of ${DateFormat('d MMM').format(rangeStart)}',
      start: rangeStart,
      end: end,
    );
  }

  @override
  Future<PeriodSummary> monthlySummary({DateTime? anchor}) async {
    final ref = anchor ?? DateTime.now();
    final start = DateTime(ref.year, ref.month);
    final end = DateTime(ref.year, ref.month + 1, 0, 23, 59, 59, 999);
    return _buildSummary(
      label: DateFormat('MMMM yyyy').format(start),
      start: start,
      end: end,
    );
  }

  Future<PeriodSummary> _buildSummary({
    required String label,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _db.getTransactionsBetween(start, end);
    final transactions = rows.map(_transactionFromRow).toList();

    var totalSpend = 0.0;
    var totalIncome = 0.0;
    final byCategory = <String, ({double amount, int count})>{};

    for (final tx in transactions) {
      if (tx.type == TransactionType.debit) {
        totalSpend += tx.amount;
        final key = tx.categoryId ?? 'uncategorized';
        final current = byCategory[key];
        byCategory[key] = (
          amount: (current?.amount ?? 0) + tx.amount,
          count: (current?.count ?? 0) + 1,
        );
      } else {
        totalIncome += tx.amount;
      }
    }

    final categories = await _categories.loadCategories();
    final breakdown = byCategory.entries.map((entry) {
      final cat = categories.firstWhere(
        (c) => c.id == entry.key,
        orElse: () => _categories.uncategorized(),
      );
      return CategoryBreakdown(
        category: cat,
        amount: entry.value.amount,
        transactionCount: entry.value.count,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return PeriodSummary(
      label: label,
      start: start,
      end: end,
      totalSpend: totalSpend,
      totalIncome: totalIncome,
      breakdown: breakdown,
    );
  }

  Transaction _transactionFromRow(Map<String, dynamic> row) {
    return Transaction(
      id: row['id'] as String?,
      rawIngestId: row['raw_ingest_id'] as String? ?? '',
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      currency: row['currency'] as String? ?? 'INR',
      merchant: row['merchant'] as String?,
      timestamp: DateTime.parse(row['timestamp'] as String),
      categoryId: row['category_id'] as String?,
      paymentSourceId: row['payment_source_id'] as String?,
      unmatched: (row['unmatched'] as int? ?? 0) == 1,
      ambiguous: (row['ambiguous'] as int? ?? 0) == 1,
      type: TransactionType.fromString(row['type'] as String? ?? 'debit'),
    );
  }

  DateTime _endOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999);

  @override
  Future<({int rawIngests, int transactions})> localCounts() async {
    return (
      rawIngests: await _db.countRawIngests(),
      transactions: await _db.countTransactions(),
    );
  }
}
