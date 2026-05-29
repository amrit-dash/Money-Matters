import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_router.dart';
import 'dashboard_repository.dart';
import 'mock_dashboard_repository.dart';

enum _PeriodMode { weekly, monthly }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.repository});

  final DashboardRepository? repository;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardRepository _repo;
  _PeriodMode _mode = _PeriodMode.weekly;
  PeriodSummary? _summary;
  bool _loading = true;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MockDashboardRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = _mode == _PeriodMode.weekly
        ? await _repo.weeklySummary()
        : await _repo.monthlySummary();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

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
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 24),
                  if (_summary != null) ...[
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
