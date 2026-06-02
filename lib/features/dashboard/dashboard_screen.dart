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
  PeriodSummary? _summary;
  PeriodSummary? _priorSummary;
  bool _loading = true;
  String? _syncMessage;
  int _rawIngestCount = 0;
  int _transactionCount = 0;
  int _needsInputCount = 0;
  bool _showPipelineSummary = false;
  StreamSubscription<IngestDrainResult>? _drainSubscription;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _drainSubscription = widget.queueDrain?.onDrained.listen((_) {
      if (mounted) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _drainSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load({bool syncQueue = false}) async {
    setState(() {
      _loading = true;
      _syncMessage = syncQueue ? 'Syncing queue…' : null;
    });

    if (syncQueue && widget.queueDrain != null) {
      final result = await widget.queueDrain!.drainIfAuthenticated();
      if (mounted && result != null) {
        _syncMessage = result.formatSyncMessage();
      }
    }

    final summary = _mode == _PeriodMode.weekly
        ? await widget.repository.weeklySummary(anchor: _periodAnchor)
        : await widget.repository.monthlySummary(anchor: _periodAnchor);
    final priorSummary = _mode == _PeriodMode.weekly
        ? await widget.repository.weeklySummary(
            anchor: _periodAnchor.subtract(const Duration(days: 7)),
          )
        : await widget.repository.monthlySummary(
            anchor: DateTime(_periodAnchor.year, _periodAnchor.month - 1, 15),
          );
    final counts = await widget.repository.localCounts();
    final needsInput = await widget.reviewRepository.needsInputCount();
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
      _summary = summary;
      _priorSummary = priorSummary;
      _rawIngestCount = counts.rawIngests;
      _transactionCount = counts.transactions;
      _needsInputCount = needsInput;
      _showPipelineSummary = showPipeline;
      _loading = false;
      if (!syncQueue) _syncMessage = null;
    });
    widget.onInboxCountChanged?.call();
  }

  bool get _isCurrentPeriod {
    final summary = _summary;
    if (summary == null) return true;
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
    _load();
  }

  void _resetToCurrentPeriod() {
    setState(() => _periodAnchor = DateTime.now());
    _load();
  }

  String get _priorPeriodLabel {
    if (_mode == _PeriodMode.weekly) return 'prior week';
    final prior = DateTime(_periodAnchor.year, _periodAnchor.month - 1);
    return DateFormat('MMMM').format(prior);
  }

  bool get _isEmpty =>
      _summary != null &&
      _summary!.totalSpend == 0 &&
      _summary!.totalIncome == 0 &&
      _summary!.breakdown.isEmpty &&
      _summary!.unmatchedCount == 0;

  String _sourceSubtitle(SourceBreakdown row) {
    final source = row.source;
    final type = source.type.name;
    final last4 = source.last4;
    final suffix = last4 != null ? ' ···· $last4' : '';
    return '$type$suffix · ${row.transactionCount} transactions';
  }

  Future<void> _openCategory(String categoryId, String title) async {
    final summary = _summary;
    if (summary == null) return;
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
    if (mounted) _load();
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
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.embeddedInShell;
    final scaffold = Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(shell ? 'Overview' : 'Dashboard'),
          actions: shell
              ? null
              : [
                  IconButton(
                    icon: Badge(
                      isLabelVisible: _needsInputCount > 0,
                      label: Text('$_needsInputCount'),
                      child: const Icon(Icons.inbox_outlined),
                    ),
                    tooltip: 'Needs your input',
                    onPressed: () async {
                      await Navigator.pushNamed(context, AppRoutes.review);
                      if (mounted) _load();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cloud_sync_outlined),
                    tooltip: 'Recovery queue',
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.recovery),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_outline),
                    tooltip: 'Profile',
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.profile),
                  ),
                ],
        ),
        body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(syncQueue: true),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (shell)
                    Text(
                      'Your spend at a glance',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
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
                      _load();
                    },
                  ),
                  const SizedBox(height: AppSpacing.item),
                  _PeriodNavigator(
                    label: _summary?.label ?? '',
                    canGoNext: !_isCurrentPeriod,
                    onPrevious: () => _shiftPeriod(-1),
                    onNext: _isCurrentPeriod ? null : () => _shiftPeriod(1),
                    onToday: _isCurrentPeriod ? null : _resetToCurrentPeriod,
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
                              Icons.sync,
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
                  if (_summary != null && _isEmpty)
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
                  else if (_summary != null) ...[
                    if (_priorSummary != null)
                      PeriodComparisonCard(
                        currentSpend: _summary!.totalSpend,
                        priorSpend: _priorSummary!.totalSpend,
                        priorLabel: _priorPeriodLabel,
                      ),
                    if (_priorSummary != null)
                      const SizedBox(height: AppSpacing.item),
                    HeroSpendCard(
                      label: 'Total spend',
                      amount: _currency.format(_summary!.totalSpend),
                      secondaryLabel: _summary!.totalIncome > 0
                          ? 'Income'
                          : null,
                      secondaryAmount: _summary!.totalIncome > 0
                          ? _currency.format(_summary!.totalIncome)
                          : null,
                    ),
                    if (_summary!.breakdown.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.item),
                      CategorySpendBarChart(
                        breakdown: _summary!.breakdown,
                        totalSpend: _summary!.totalSpend,
                      ),
                    ],
                    if (_summary!.sources.isNotEmpty ||
                        _summary!.unmatchedCount > 0) ...[
                      const SizedBox(height: AppSpacing.section),
                      AppSectionHeader(
                        title: 'By account',
                        subtitle: 'Tap a bank or card to see its transactions',
                        icon: Icons.account_balance_outlined,
                      ),
                      ..._summary!.sources.map(
                        (row) => _SourceRow(
                          name: row.displayName,
                          subtitle: _sourceSubtitle(row),
                          amount: _currency.format(row.amount),
                          share: row.shareOf(_summary!.totalSpend),
                          count: row.transactionCount,
                          onTap: () => _openSource(
                            row.source.id,
                            row.displayName,
                          ),
                        ),
                      ),
                      if (_summary!.unmatchedCount > 0)
                        _SourceRow(
                          name: 'Unmatched',
                          subtitle:
                              '${_summary!.unmatchedCount} transactions · '
                              'not linked to a saved account',
                          amount: _currency.format(_summary!.unmatchedSpend),
                          share: 0,
                          count: _summary!.unmatchedCount,
                          muted: true,
                          onTap: () => _openSource(null, 'Unmatched'),
                        ),
                    ],
                    const SizedBox(height: AppSpacing.section),
                    AppSectionHeader(
                      title: 'By category',
                      subtitle: _summary!.breakdown.isEmpty
                          ? null
                          : 'Tap a category to see its transactions',
                      icon: Icons.pie_chart_outline,
                    ),
                    if (_summary!.breakdown.isEmpty)
                      Text(
                        'No categorized spend in this period.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      )
                    else
                      ..._summary!.breakdown.asMap().entries.map(
                        (entry) => _CategoryRow(
                          name: entry.value.category.name,
                          amount: _currency.format(entry.value.amount),
                          share: entry.value.shareOf(_summary!.totalSpend),
                          count: entry.value.transactionCount,
                          accentIndex: entry.key,
                          onTap: () => _openCategory(
                            entry.value.category.id,
                            entry.value.category.name,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
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
    this.onToday,
    this.canGoNext = true,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onToday;
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
            if (onToday != null)
              TextButton(
                onPressed: onToday,
                child: const Text('Today'),
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
