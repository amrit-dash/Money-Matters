import 'package:intl/intl.dart';
import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';

import '../../core/db/local_database.dart';
import '../../services/category_service.dart';
import '../../services/payment_source_service.dart';
import 'dashboard_repository.dart';

/// Dashboard analytics from local SQLite transactions.
///
/// Unmatched transactions (no saved bank/card) are excluded from headline
/// totals and the category breakdown, and surfaced separately so promo or
/// unknown-source noise never inflates spend.
class LocalDashboardRepository implements DashboardRepository {
  LocalDashboardRepository({
    required LocalDatabase localDatabase,
    required CategoryService categoryService,
    PaymentSourceService? paymentSourceService,
  })  : _db = localDatabase,
        _categories = categoryService,
        _paymentSources = paymentSourceService;

  final LocalDatabase _db;
  final CategoryService _categories;
  final PaymentSourceService? _paymentSources;

  List<PaymentSource>? _sourceCache;

  Future<List<PaymentSource>> _loadSources() async {
    if (_sourceCache != null) return _sourceCache!;
    try {
      _sourceCache = await _paymentSources?.loadAll() ?? const [];
    } catch (_) {
      _sourceCache = const [];
    }
    return _sourceCache!;
  }

  /// True when a debit has no linked, known payment source.
  static bool isUnmatched(Transaction tx, Set<String> knownSourceIds) {
    if (tx.unmatched || tx.paymentSourceId == null) return true;
    return !knownSourceIds.contains(tx.paymentSourceId!);
  }

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
    final transactions = rows.map(Transaction.fromSqlite).toList();
    final sources = await _loadSources();
    final categories = await _categories.loadCategories();

    return summarize(
      label: label,
      start: start,
      end: end,
      transactions: transactions,
      sources: sources,
      categories: categories,
      uncategorized: _categories.uncategorized(),
    );
  }

  /// Pure aggregation used by the dashboard. Unmatched debits (no saved
  /// bank/card) and credits are excluded from [PeriodSummary.totalSpend] and
  /// the category breakdown; unmatched spend is surfaced separately so promo
  /// or unknown-source noise never inflates headline totals.
  static PeriodSummary summarize({
    required String label,
    required DateTime start,
    required DateTime end,
    required List<Transaction> transactions,
    required List<PaymentSource> sources,
    required List<Category> categories,
    required Category uncategorized,
  }) {
    final sourcesById = {for (final s in sources) s.id: s};
    final knownSourceIds = sourcesById.keys.toSet();

    var totalSpend = 0.0;
    var totalIncome = 0.0;
    var unmatchedSpend = 0.0;
    var unmatchedCount = 0;
    final byCategory = <String, ({double amount, int count})>{};
    final bySource = <String, ({double amount, int count})>{};

    for (final tx in transactions) {
      if (tx.excluded) continue;

      if (tx.type == TransactionType.credit) {
        totalIncome += tx.amount;
        continue;
      }

      if (isUnmatched(tx, knownSourceIds)) {
        unmatchedSpend += tx.amount;
        unmatchedCount += 1;
        continue;
      }

      totalSpend += tx.amount;

      final catKey = tx.categoryId ?? 'uncategorized';
      final cat = byCategory[catKey];
      byCategory[catKey] = (
        amount: (cat?.amount ?? 0) + tx.amount,
        count: (cat?.count ?? 0) + 1,
      );

      final srcKey = tx.paymentSourceId!;
      final src = bySource[srcKey];
      bySource[srcKey] = (
        amount: (src?.amount ?? 0) + tx.amount,
        count: (src?.count ?? 0) + 1,
      );
    }

    final breakdown = byCategory.entries.map((entry) {
      final cat = categories.firstWhere(
        (c) => c.id == entry.key,
        orElse: () => uncategorized,
      );
      return CategoryBreakdown(
        category: cat,
        amount: entry.value.amount,
        transactionCount: entry.value.count,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final sourceBreakdown = bySource.entries
        .where((entry) => sourcesById.containsKey(entry.key))
        .map((entry) {
      return SourceBreakdown(
        source: sourcesById[entry.key]!,
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
      sources: sourceBreakdown,
      unmatchedSpend: unmatchedSpend,
      unmatchedCount: unmatchedCount,
    );
  }

  /// Filters transactions for a category drill-down in a period window.
  static List<Transaction> filterCategoryTransactions({
    required List<Transaction> transactions,
    required String categoryId,
    required Set<String> knownSourceIds,
  }) {
    return transactions.where((tx) {
      if (tx.excluded) return false;
      if (tx.type != TransactionType.debit) return false;
      if (isUnmatched(tx, knownSourceIds)) return false;
      final catKey = tx.categoryId ?? 'uncategorized';
      return catKey == categoryId;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Filters transactions for a source drill-down (null = unmatched bucket).
  static List<Transaction> filterSourceTransactions({
    required List<Transaction> transactions,
    required String? paymentSourceId,
    required Set<String> knownSourceIds,
  }) {
    return transactions.where((tx) {
      if (tx.excluded) return false;
      if (paymentSourceId == null) {
        return tx.type == TransactionType.debit &&
            isUnmatched(tx, knownSourceIds);
      }
      return !isUnmatched(tx, knownSourceIds) &&
          tx.paymentSourceId == paymentSourceId;
    }).toList();
  }

  @override
  Future<List<Transaction>> categoryTransactions({
    required String categoryId,
    required DateTime start,
    required DateTime end,
  }) async {
    final sources = await _loadSources();
    final knownSourceIds = sources.map((s) => s.id).toSet();
    final rows = await _db.getTransactionsBetween(start, end);
    return filterCategoryTransactions(
      transactions: rows.map(Transaction.fromSqlite).toList(),
      categoryId: categoryId,
      knownSourceIds: knownSourceIds,
    );
  }

  @override
  Future<List<Transaction>> sourceTransactions(String? paymentSourceId) async {
    final sources = await _loadSources();
    final knownSourceIds = sources.map((s) => s.id).toSet();
    final rows = await _db.getTransactionsForSource(paymentSourceId);
    return filterSourceTransactions(
      transactions: rows.map(Transaction.fromSqlite).toList(),
      paymentSourceId: paymentSourceId,
      knownSourceIds: knownSourceIds,
    );
  }

  @override
  Future<PaymentSource?> paymentSourceById(String id) async {
    final sources = await _loadSources();
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
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
