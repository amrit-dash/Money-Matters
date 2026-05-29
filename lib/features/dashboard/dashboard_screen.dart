import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_router.dart';
import '../../ingest/ingest_queue_drain.dart';
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

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool syncQueue = false}) async {
    setState(() {
      _loading = true;
      _syncMessage = syncQueue ? 'Syncing queue…' : null;
    });

    if (syncQueue && widget.queueDrain != null) {
      final result = await widget.queueDrain!.drainIfAuthenticated();
      if (mounted && result != null && result.totalSynced > 0) {
        _syncMessage = 'Synced ${result.totalSynced} item(s)';
      }
    }

    final summary = _mode == _PeriodMode.weekly
        ? await widget.repository.weeklySummary()
        : await widget.repository.monthlySummary();
    if (!mounted) return;
    setState(() {
      _summary = summary;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sms_outlined),
            tooltip: 'Connect SMS',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.connectSms),
          ),
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Review flagged',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.review),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Recovery',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.recovery),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(syncQueue: true),
              child: ListView(
                padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 12),
                    Text(
                      _syncMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_summary != null && _isEmpty)
                    _EmptyState(
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
                    const SizedBox(height: 16),
                    _TotalCard(
                      label: 'Total spend',
                      amount: _currency.format(_summary!.totalSpend),
                    ),
                    if (_summary!.totalIncome > 0) ...[
                      const SizedBox(height: 8),
                      _TotalCard(
                        label: 'Income',
                        amount: _currency.format(_summary!.totalIncome),
                        muted: true,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'By category',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_summary!.breakdown.isEmpty)
                      Text(
                        'No categorized spend in this period.',
                        style: Theme.of(context).textTheme.bodyMedium,
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onConnectSms,
    required this.onRecovery,
  });

  final VoidCallback onConnectSms;
  final VoidCallback onRecovery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Send a test SMS via Shortcuts, or paste missed messages in Recovery.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onConnectSms,
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Connect SMS'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRecovery,
            icon: const Icon(Icons.sync),
            label: const Text('Open Recovery'),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.amount,
    this.muted = false,
  });

  final String label;
  final String amount;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            Text(
              amount,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: muted ? Theme.of(context).colorScheme.outline : null,
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name)),
              Text(amount),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: share.clamp(0, 1)),
          Text(
            '$count transactions · ${(share * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
