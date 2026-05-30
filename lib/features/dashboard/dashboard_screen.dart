import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import '../../ingest/ingest_queue_drain.dart';
import '../../ingest/ingest_repository.dart';
import 'dashboard_repository.dart';

enum _PeriodMode { weekly, monthly }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    this.queueDrain,
  });

  final DashboardRepository repository;
  final IngestQueueDrain? queueDrain;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _PeriodMode _mode = _PeriodMode.weekly;
  PeriodSummary? _summary;
  bool _loading = true;
  String? _syncMessage;
  int _rawIngestCount = 0;
  int _transactionCount = 0;
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
        ? await widget.repository.weeklySummary()
        : await widget.repository.monthlySummary();
    final counts = await widget.repository.localCounts();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _rawIngestCount = counts.rawIngests;
      _transactionCount = counts.transactions;
      _loading = false;
      if (!syncQueue) _syncMessage = null;
    });
  }

  bool get _isEmpty =>
      _summary != null &&
      _summary!.totalSpend == 0 &&
      _summary!.totalIncome == 0 &&
      _summary!.breakdown.isEmpty;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Review flagged',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.review),
            ),
            IconButton(
              icon: const Icon(Icons.inbox_outlined),
              tooltip: 'Recovery queue',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.recovery),
            ),
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
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
                      setState(() => _mode = s.first);
                      _load();
                    },
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
                  if (_rawIngestCount > 0 || _transactionCount > 0) ...[
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
                    _EmptyState(
                      rawIngestCount: _rawIngestCount,
                      transactionCount: _transactionCount,
                      onConnectSms: () =>
                          Navigator.pushNamed(context, AppRoutes.connectSms),
                      onRecovery: () =>
                          Navigator.pushNamed(context, AppRoutes.recovery),
                    )
                  else if (_summary != null) ...[
                    Text(
                      _summary!.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.item),
                    _TotalCard(
                      label: 'Total spend',
                      amount: _currency.format(_summary!.totalSpend),
                      emphasized: true,
                    ),
                    if (_summary!.totalIncome > 0) ...[
                      const SizedBox(height: AppSpacing.tight),
                      _TotalCard(
                        label: 'Income',
                        amount: _currency.format(_summary!.totalIncome),
                        muted: true,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.section),
                    AppSectionHeader(title: 'By category'),
                    if (_summary!.breakdown.isEmpty)
                      Text(
                        'No categorized spend in this period.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      )
                    else
                      ..._summary!.breakdown.map(
                        (row) => _CategoryRow(
                          name: row.category.name,
                          amount: _currency.format(row.amount),
                          share: row.shareOf(_summary!.totalSpend),
                          count: row.transactionCount,
                        ),
                      ),
                  ],
                ],
              ),
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

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.amount,
    this.muted = false,
    this.emphasized = false,
  });

  final String label;
  final String amount;
  final bool muted;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: emphasized
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: muted ? scheme.outline : scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
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
  });

  final String name;
  final String amount;
  final double share;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.item),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                ],
              ),
              const SizedBox(height: AppSpacing.tight),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: share.clamp(0, 1),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$count transactions · ${(share * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
