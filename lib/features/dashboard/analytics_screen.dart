import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/dashboard_charts.dart';
import '../../services/category_service.dart';
import '../review/review_repository.dart';
import '../../services/payment_source_service.dart';
import 'category_detail_screen.dart';
import 'dashboard_repository.dart';
import 'period_transactions_screen.dart';
import 'source_detail_screen.dart';

enum _PeriodMode { weekly, monthly }

/// Detailed spend analytics for the selected period.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    super.key,
    required this.repository,
    required this.reviewRepository,
    required this.categoryService,
    required this.paymentSourceService,
    this.embeddedInShell = false,
  });

  final DashboardRepository repository;
  final ReviewRepository reviewRepository;
  final CategoryService categoryService;
  final PaymentSourceService paymentSourceService;
  final bool embeddedInShell;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _PeriodMode _mode = _PeriodMode.weekly;
  DateTime _periodAnchor = DateTime.now();
  PeriodSummary? _priorSummary;
  List<PeriodSummary> _monthlyTrend = const [];

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  Stream<PeriodSummary> get _summaryStream => _mode == _PeriodMode.weekly
      ? widget.repository.watchWeeklySummary(anchor: _periodAnchor)
      : widget.repository.watchMonthlySummary(anchor: _periodAnchor);

  @override
  void initState() {
    super.initState();
    _loadAuxiliarySummaries();
  }

  Future<void> _loadAuxiliarySummaries() async {
    final priorSummary = _mode == _PeriodMode.weekly
        ? await widget.repository.weeklySummary(
            anchor: _periodAnchor.subtract(const Duration(days: 7)),
          )
        : await widget.repository.monthlySummary(
            anchor: DateTime(_periodAnchor.year, _periodAnchor.month - 1, 15),
          );
    List<PeriodSummary> trend = const [];
    if (_mode == _PeriodMode.monthly) {
      trend = await widget.repository.recentMonthlySummaries(
        anchor: _periodAnchor,
        count: 6,
      );
    }
    if (!mounted) return;
    setState(() {
      _priorSummary = priorSummary;
      _monthlyTrend = trend;
    });
  }

  bool _isCurrentPeriodFor(PeriodSummary summary) {
    final now = DateTime.now();
    return !now.isBefore(summary.start) && !now.isAfter(summary.end);
  }

  void _shiftPeriod(int direction) {
    setState(() {
      if (_mode == _PeriodMode.weekly) {
        _periodAnchor = _periodAnchor.add(Duration(days: 7 * direction));
      } else {
        _periodAnchor = DateTime(
          _periodAnchor.year,
          _periodAnchor.month + direction,
          _periodAnchor.day,
        );
      }
    });
    _loadAuxiliarySummaries();
  }

  void _resetToCurrentPeriod() {
    setState(() => _periodAnchor = DateTime.now());
    _loadAuxiliarySummaries();
  }

  String get _priorPeriodLabel {
    if (_mode == _PeriodMode.weekly) return 'prior week';
    final prior = DateTime(_periodAnchor.year, _periodAnchor.month - 1);
    return DateFormat('MMMM').format(prior);
  }

  bool _isEmpty(PeriodSummary summary) =>
      summary.totalSpend == 0 &&
      summary.totalIncome == 0 &&
      summary.breakdown.isEmpty &&
      summary.unmatchedCount == 0;

  bool get _hasPriorComparisonData =>
      _priorSummary != null && _priorSummary!.totalSpend > 0;

  String _sourceSubtitle(SourceBreakdown row) {
    final source = row.source;
    final type = source.type.name;
    final last4 = source.last4;
    final suffix = last4 != null ? ' ···· $last4' : '';
    return '$type$suffix · ${row.transactionCount} transactions';
  }

  Future<void> _openCategory(
    PeriodSummary summary,
    String categoryId,
    String title,
  ) async {
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryDetailScreen(
          dashboardRepository: widget.repository,
          reviewRepository: widget.reviewRepository,
          categoryService: widget.categoryService,
          paymentSourceService: widget.paymentSourceService,
          categoryId: categoryId,
          title: title,
          periodStart: summary.start,
          periodEnd: summary.end,
          periodLabel: summary.label,
        ),
      ),
    );
  }

  Future<void> _openSource(String? sourceId, String title) async {
    final source = sourceId == null
        ? null
        : await widget.repository.paymentSourceById(sourceId);
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SourceDetailScreen(
          dashboardRepository: widget.repository,
          reviewRepository: widget.reviewRepository,
          categoryService: widget.categoryService,
          paymentSourceService: widget.paymentSourceService,
          paymentSourceId: sourceId,
          title: title,
          source: source,
        ),
      ),
    );
  }

  void _openAllTransactions(PeriodSummary summary) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PeriodTransactionsScreen(
          dashboardRepository: widget.repository,
          reviewRepository: widget.reviewRepository,
          categoryService: widget.categoryService,
          paymentSourceService: widget.paymentSourceService,
          periodStart: summary.start,
          periodEnd: summary.end,
          periodLabel: summary.label,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PeriodSummary summary) {
    final shell = widget.embeddedInShell;
    final isCurrentPeriod = _isCurrentPeriodFor(summary);
    final isMonthly = _mode == _PeriodMode.monthly;
    final saved = periodSavedAmount(summary);
    final showCreditsChart = isMonthly && summary.totalIncome > 0;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        if (shell)
          Text(
            'Detailed breakdown for this period',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        if (shell) const SizedBox(height: AppSpacing.item),
        SegmentedButton<_PeriodMode>(
          segments: const [
            ButtonSegment(value: _PeriodMode.weekly, label: Text('Weekly')),
            ButtonSegment(value: _PeriodMode.monthly, label: Text('Monthly')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) {
            setState(() {
              _mode = s.first;
              _periodAnchor = DateTime.now();
            });
            _loadAuxiliarySummaries();
          },
        ),
        const SizedBox(height: AppSpacing.item),
        _PeriodNavigator(
          label: summary.label,
          canGoNext: !isCurrentPeriod,
          onPrevious: () => _shiftPeriod(-1),
          onNext: isCurrentPeriod ? null : () => _shiftPeriod(1),
        ),
        const SizedBox(height: AppSpacing.section),
        if (_isEmpty(summary))
          Center(
            child: AppEmptyState(
              icon: Icons.insights_outlined,
              title: 'No activity in this period',
              message:
                  'Try another week or month, or sync SMS from the Home tab.',
            ),
          )
        else ...[
          HeroSpendCard(
            label: 'Total spend',
            amount: _currency.format(summary.totalSpend),
            metricsRow: isMonthly
                ? [
                    HeroSpendMetric(
                      label: 'Income',
                      amount: _currency.format(summary.totalIncome),
                    ),
                    HeroSpendMetric(
                      label: 'Net',
                      amount: _currency.format(summary.net),
                    ),
                  ]
                : const [],
            icon: Icons.insights_outlined,
          ),
          if (_hasPriorComparisonData) ...[
            const SizedBox(height: AppSpacing.item),
            PeriodComparisonCard(
              currentSpend: summary.totalSpend,
              priorSpend: _priorSummary!.totalSpend,
              priorLabel: _priorPeriodLabel,
            ),
          ],
          if (summary.breakdown.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.item),
            CategorySpendPieChart(
              breakdown: summary.breakdown,
              totalSpend: summary.totalSpend,
            ),
          ],
          if (showCreditsChart) ...[
            const SizedBox(height: AppSpacing.item),
            CreditsSpendSavedChart(
              totalIncome: summary.totalIncome,
              totalSpend: summary.totalSpend,
              saved: saved,
            ),
          ],
          if (isMonthly && _monthlyTrend.length >= 2) ...[
            const SizedBox(height: AppSpacing.item),
            MonthlyTrendLineChart(summaries: _monthlyTrend),
          ],
          if (summary.breakdown.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.item),
            CategorySpendBarChart(
              breakdown: summary.breakdown,
              totalSpend: summary.totalSpend,
              maxBars: 10,
            ),
          ],
          if (summary.sources.isNotEmpty || summary.unmatchedCount > 0) ...[
            const SizedBox(height: AppSpacing.section),
            AppSectionHeader(
              title: 'By account',
              subtitle: 'Tap a bank or card to see its transactions',
              icon: Icons.account_balance_outlined,
            ),
            ...summary.sources.map(
              (row) => _SourceRow(
                name: row.displayName,
                subtitle: _sourceSubtitle(row),
                amount: _currency.format(row.amount),
                share: row.shareOf(summary.totalSpend),
                count: row.transactionCount,
                onTap: () => _openSource(row.source.id, row.displayName),
              ),
            ),
            if (summary.unmatchedCount > 0)
              _SourceRow(
                name: 'Unmatched',
                subtitle:
                    '${summary.unmatchedCount} transactions · '
                    'not linked to a saved account',
                amount: _currency.format(summary.unmatchedSpend),
                share: 0,
                count: summary.unmatchedCount,
                muted: true,
                onTap: () => _openSource(null, 'Unmatched'),
              ),
          ],
          const SizedBox(height: AppSpacing.section),
          AppSectionHeader(
            title: 'By category',
            subtitle: summary.breakdown.isEmpty
                ? null
                : 'Tap a category to see its transactions',
            icon: Icons.pie_chart_outline,
          ),
          if (summary.breakdown.isEmpty)
            Text(
              'No categorized spend in this period.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            ...summary.breakdown.asMap().entries.map(
              (entry) => _CategoryRow(
                name: entry.value.category.name,
                amount: _currency.format(entry.value.amount),
                share: entry.value.shareOf(summary.totalSpend),
                count: entry.value.transactionCount,
                accentIndex: entry.key,
                onTap: () => _openCategory(
                  summary,
                  entry.value.category.id,
                  entry.value.category.name,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.section),
          FilledButton.icon(
            onPressed: () => _openAllTransactions(summary),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('View all transactions'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PeriodSummary>(
      stream: _summaryStream,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final isCurrentPeriod =
            summary != null && _isCurrentPeriodFor(summary);
        final showTodayAction = summary != null && !isCurrentPeriod;
        final todayAction = showTodayAction
            ? IconButton(
                icon: const Icon(Icons.today_outlined),
                tooltip: 'Back to today',
                onPressed: _resetToCurrentPeriod,
              )
            : null;

        final body = summary == null
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context, summary);

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Analytics'),
            actions: todayAction == null
                ? null
                : [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: todayAction,
                    ),
                  ],
          ),
          body: body,
        );
      },
    );
  }
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({
    required this.label,
    required this.onPrevious,
    this.onNext,
    this.canGoNext = true,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous period',
              onPressed: onPrevious,
            ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next period',
              onPressed: canGoNext ? onNext : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.share,
    required this.count,
    this.onTap,
    this.muted = false,
  });

  final String name;
  final String subtitle;
  final String amount;
  final double share;
  final int count;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.tight),
      child: Card(
        color: muted
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: muted
                      ? scheme.surfaceContainerHighest
                      : scheme.primaryContainer,
                  child: Icon(
                    muted
                        ? Icons.help_outline
                        : Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: muted
                        ? scheme.onSurfaceVariant
                        : scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  amount,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: muted
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, color: scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.amount,
    required this.share,
    required this.count,
    this.accentIndex = 0,
    this.onTap,
  });

  final String name;
  final String amount;
  final double share;
  final int count;
  final int accentIndex;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final barColor = categoryAccentColor(scheme, accentIndex);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.tight),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      amount,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: scheme.outline),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.tight),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share.clamp(0, 1),
                    minHeight: 6,
                    backgroundColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    color: barColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$count transactions · ${(share * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
