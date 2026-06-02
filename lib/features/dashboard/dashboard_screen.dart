import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/dashboard_charts.dart';
import '../../ingest/ingest_queue_drain.dart';
import '../../ingest/ingest_repository.dart';
import '../../services/category_service.dart';
import '../recovery/recovery_repository.dart';
import '../review/review_repository.dart';
import '../../services/payment_source_service.dart';
import 'dashboard_repository.dart';
import 'category_detail_screen.dart';
import 'source_detail_screen.dart';

enum _PeriodMode { weekly, monthly }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.reviewRepository,
    required this.categoryService,
    required this.paymentSourceService,
    this.recoveryRepository,
    this.queueDrain,
    this.embeddedInShell = false,
    this.onInboxCountChanged,
  });

  final DashboardRepository repository;
  final ReviewRepository reviewRepository;
  final CategoryService categoryService;
  final PaymentSourceService paymentSourceService;
  final RecoveryRepository? recoveryRepository;
  final IngestQueueDrain? queueDrain;
  final bool embeddedInShell;
  final VoidCallback? onInboxCountChanged;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _PeriodMode _mode = _PeriodMode.weekly;
  DateTime _periodAnchor = DateTime.now();
  PeriodSummary? _priorSummary;
  String? _syncMessage;
  int _rawIngestCount = 0;
  int _transactionCount = 0;
  bool _showPipelineSummary = false;
  bool _syncing = false;
  Timer? _syncMessageTimer;
  Timer? _pipelineTimer;
  StreamSubscription<IngestDrainResult>? _drainSubscription;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  Stream<PeriodSummary> get _summaryStream => _mode == _PeriodMode.weekly
      ? widget.repository.watchWeeklySummary(anchor: _periodAnchor)
      : widget.repository.watchMonthlySummary(anchor: _periodAnchor);

  @override
  void initState() {
    super.initState();
    _drainSubscription = widget.queueDrain?.onDrained.listen((_) {
      if (mounted) _loadAuxiliaryData();
    });
    _loadAuxiliaryData();
  }

  @override
  void dispose() {
    _syncMessageTimer?.cancel();
    _pipelineTimer?.cancel();
    _drainSubscription?.cancel();
    super.dispose();
  }

  void _scheduleSyncMessageDismiss() {
    _syncMessageTimer?.cancel();
    if (_syncMessage != null && _syncMessage != 'Syncing queue…') {
      _syncMessageTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _syncMessage = null);
      });
    }
  }

  void _schedulePipelineSummaryDismiss() {
    _pipelineTimer?.cancel();
    if (_showPipelineSummary) {
      _pipelineTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showPipelineSummary = false);
      });
    }
  }

  Future<void> _loadAuxiliaryData() async {
    final priorSummary = _mode == _PeriodMode.weekly
        ? await widget.repository.weeklySummary(
            anchor: _periodAnchor.subtract(const Duration(days: 7)),
          )
        : await widget.repository.monthlySummary(
            anchor: DateTime(_periodAnchor.year, _periodAnchor.month - 1, 15),
          );
    final counts = await widget.repository.localCounts();
    var showPipeline = false;
    final recovery = widget.recoveryRepository;
    if (recovery != null) {
      try {
        final status = await recovery.status();
        showPipeline = status.pendingMessageCount > 0 ||
            status.pendingParseJobCount > 0 ||
            status.failedParseCount > 0;
      } catch (_) {
        showPipeline = counts.rawIngests > counts.transactions;
      }
    } else {
      showPipeline = counts.rawIngests > counts.transactions;
    }
    if (!mounted) return;
    setState(() {
      _priorSummary = priorSummary;
      _rawIngestCount = counts.rawIngests;
      _transactionCount = counts.transactions;
      _showPipelineSummary = showPipeline;
    });
    if (showPipeline) _schedulePipelineSummaryDismiss();
    widget.onInboxCountChanged?.call();
  }

  Future<void> _syncQueue() async {
    if (widget.queueDrain == null) return;
    setState(() {
      _syncing = true;
      _syncMessage = 'Syncing queue…';
    });
    final result = await widget.queueDrain!.drainIfAuthenticated();
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _syncMessage = result?.formatSyncMessage();
    });
    _scheduleSyncMessageDismiss();
    await _loadAuxiliaryData();
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
    _loadAuxiliaryData();
  }

  void _resetToCurrentPeriod() {
    setState(() => _periodAnchor = DateTime.now());
    _loadAuxiliaryData();
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

  Widget _buildBody(BuildContext context, PeriodSummary summary) {
    final shell = widget.embeddedInShell;
    final isCurrentPeriod = _isCurrentPeriodFor(summary);

    return RefreshIndicator(
      onRefresh: _syncQueue,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (shell)
            Text(
              'Your spend at a glance',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          if (shell) const SizedBox(height: AppSpacing.item),
          SegmentedButton<_PeriodMode>(
            segments: const [
              ButtonSegment(
                value: _PeriodMode.weekly,
                label: Text('Weekly'),
              ),
              ButtonSegment(
                value: _PeriodMode.monthly,
                label: Text('Monthly'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) {
              setState(() {
                _mode = s.first;
                _periodAnchor = DateTime.now();
              });
              _loadAuxiliaryData();
            },
          ),
          const SizedBox(height: AppSpacing.item),
          _PeriodNavigator(
            label: summary.label,
            canGoNext: !isCurrentPeriod,
            onPrevious: () => _shiftPeriod(-1),
            onNext: isCurrentPeriod ? null : () => _shiftPeriod(1),
          ),
          if (_syncMessage != null) ...[
            const SizedBox(height: AppSpacing.item),
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _syncing ? Icons.sync : Icons.check_circle_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _syncMessage!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_showPipelineSummary) ...[
            const SizedBox(height: AppSpacing.item),
            _PipelineSummary(
              synced: _rawIngestCount,
              parsed: _transactionCount,
              onOpenRecovery: () =>
                  Navigator.pushNamed(context, AppRoutes.recovery),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          if (_isEmpty(summary))
            Center(
              child: _EmptyState(
                rawIngestCount: _rawIngestCount,
                transactionCount: _transactionCount,
                onConnectSms: () =>
                    Navigator.pushNamed(context, AppRoutes.connectSms),
                onRecovery: () =>
                    Navigator.pushNamed(context, AppRoutes.recovery),
              ),
            )
          else ...[
            HeroSpendCard(
              label: 'Total spend',
              amount: _currency.format(summary.totalSpend),
              secondaryLabel:
                  summary.totalIncome > 0 ? 'Income' : null,
              secondaryAmount: summary.totalIncome > 0
                  ? _currency.format(summary.totalIncome)
                  : null,
            ),
            if (summary.breakdown.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.item),
              CategorySpendBarChart(
                breakdown: summary.breakdown,
                totalSpend: summary.totalSpend,
              ),
            ],
            if (_hasPriorComparisonData) ...[
              const SizedBox(height: AppSpacing.section),
              PeriodComparisonCard(
                currentSpend: summary.totalSpend,
                priorSpend: _priorSummary!.totalSpend,
                priorLabel: _priorPeriodLabel,
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
                  onTap: () => _openSource(
                    row.source.id,
                    row.displayName,
                  ),
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
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.embeddedInShell;
    final scaffold = StreamBuilder<PeriodSummary>(
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
            title: Text(shell ? 'Overview' : 'Dashboard'),
            actions: shell
                ? (todayAction == null
                    ? null
                    : [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: todayAction,
                        ),
                      ])
                : [
                    ?todayAction,
                    StreamBuilder<int>(
                      stream: widget.reviewRepository.watchNeedsInputCount(),
                      builder: (context, countSnapshot) {
                        final inboxCount = countSnapshot.data ?? 0;
                        return IconButton(
                          icon: Badge(
                            isLabelVisible: inboxCount > 0,
                            label: Text('$inboxCount'),
                            child: const Icon(Icons.inbox_outlined),
                          ),
                          tooltip: 'Needs your input',
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.review);
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cloud_sync_outlined),
                      tooltip: 'Recovery queue',
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.recovery),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: const Icon(Icons.person_outline),
                        tooltip: 'Profile',
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.profile),
                      ),
                    ),
                  ],
          ),
          body: body,
        );
      },
    );

    if (shell) return scaffold;
    return PopScope(canPop: false, child: scaffold);
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

class _PipelineSummary extends StatelessWidget {
  const _PipelineSummary({
    required this.synced,
    required this.parsed,
    required this.onOpenRecovery,
  });

  final int synced;
  final int parsed;
  final VoidCallback onOpenRecovery;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onOpenRecovery,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$synced synced · $parsed parsed',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to view recovery queue',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.rawIngestCount,
    required this.transactionCount,
    required this.onConnectSms,
    required this.onRecovery,
  });

  final int rawIngestCount;
  final int transactionCount;
  final VoidCallback onConnectSms;
  final VoidCallback onRecovery;

  String get _title {
    if (rawIngestCount > 0 && transactionCount == 0) {
      return 'Messages synced, nothing parsed';
    }
    return 'No spend in this period';
  }

  String get _message {
    if (rawIngestCount > 0 && transactionCount == 0) {
      return '$rawIngestCount SMS stored locally but none became transactions. '
          'Check bank SMS format in Recovery, or add payment sources in Accounts.';
    }
    if (rawIngestCount > 0) {
      return '$rawIngestCount SMS synced but none fall in this period. '
          'Try Monthly view or pull down to sync.';
    }
    return 'Connect bank SMS via Shortcuts, then pull down to sync. '
        'Paste missed messages in Recovery.';
  }

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.receipt_long_outlined,
      title: _title,
      message: _message,
      primaryAction: FilledButton.icon(
        onPressed: onConnectSms,
        icon: const Icon(Icons.sms_outlined),
        label: const Text('Connect SMS'),
      ),
      secondaryAction: OutlinedButton.icon(
        onPressed: onRecovery,
        icon: const Icon(Icons.inbox_outlined),
        label: const Text('Open Recovery'),
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
        color: muted ? scheme.surfaceContainerHighest.withValues(alpha: 0.4) : null,
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
                    muted ? Icons.help_outline : Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: muted ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
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
                        color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
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
