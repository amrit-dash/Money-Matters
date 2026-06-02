import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';

import '../../app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import '../../ingest/ingest_queue_drain.dart';
import '../../ingest/ingest_repository.dart';
import '../../services/category_service.dart';
import '../accounts/payment_source_widgets.dart';
import '../recovery/recovery_repository.dart';
import '../review/review_repository.dart';
import '../../services/payment_source_service.dart';
import '../transactions/transaction_detail_screen.dart';
import 'dashboard_repository.dart';

enum _OverviewMode { today, thisWeek }

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
  _OverviewMode _mode = _OverviewMode.today;
  String? _syncMessage;
  int _rawIngestCount = 0;
  int _transactionCount = 0;
  bool _showPipelineSummary = false;
  bool _syncing = false;
  Timer? _syncMessageTimer;
  Timer? _pipelineTimer;
  StreamSubscription<IngestDrainResult>? _drainSubscription;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  static final _dateFormat = DateFormat('d MMM, h:mm a');

  Stream<PeriodSummary> get _summaryStream => _mode == _OverviewMode.today
      ? widget.repository.watchDailySummary()
      : widget.repository.watchWeeklySummary();

  DateTime get _transactionListStart {
    final now = DateTime.now();
    if (_mode == _OverviewMode.today) {
      return DateTime(now.year, now.month, now.day);
    }
    final endDay = DateTime(now.year, now.month, now.day);
    return endDay.subtract(const Duration(days: 6));
  }

  DateTime get _transactionListEnd {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  String get _transactionSectionTitle =>
      _mode == _OverviewMode.today ? 'Today\'s transactions' : 'Last 7 days';

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

  void _toggleMode() {
    setState(() {
      _mode = _mode == _OverviewMode.today
          ? _OverviewMode.thisWeek
          : _OverviewMode.today;
    });
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

  bool _isEmpty(PeriodSummary summary) =>
      summary.totalSpend == 0 &&
      summary.totalIncome == 0 &&
      summary.breakdown.isEmpty &&
      summary.unmatchedCount == 0;

  Future<void> _openTransaction(
    BuildContext context, {
    required Transaction tx,
    required Map<String, String> sourceNames,
    required Map<String, String> categoryNames,
  }) async {
    PaymentSource? source;
    final sourceId = tx.paymentSourceId;
    if (sourceId != null) {
      source = await widget.repository.paymentSourceById(sourceId);
    }
    if (!context.mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transaction: tx,
          reviewRepository: widget.reviewRepository,
          categoryService: widget.categoryService,
          paymentSourceService: widget.paymentSourceService,
          paymentSourceName: source?.name ?? sourceNames[sourceId],
        ),
      ),
    );
  }

  Widget _buildTransactionList(BuildContext context) {
    return StreamBuilder<List<PaymentSource>>(
      stream: widget.paymentSourceService.watchAll(),
      builder: (context, sourcesSnapshot) {
        final sourceNames = {
          for (final s
              in visiblePaymentSources(sourcesSnapshot.data ?? const []))
            s.id: s.name,
        };

        return StreamBuilder<List<Category>>(
          stream: widget.categoryService.watchCategories(),
          builder: (context, categoriesSnapshot) {
            final categoryNames = <String, String>{
              for (final c in categoriesSnapshot.data ?? const []) c.id: c.name,
            };

            return StreamBuilder<List<Transaction>>(
              stream: widget.repository.watchPeriodTransactions(
                start: _transactionListStart,
                end: _transactionListEnd,
              ),
              builder: (context, snapshot) {
                final items = snapshot.data;
                if (items == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.item),
                    child: Text(
                      _mode == _OverviewMode.today
                          ? 'No transactions recorded today.'
                          : 'No transactions in the last 7 days.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final tx in items)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.tight),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            title: Text(
                              tx.displayMerchant ?? 'Unknown merchant',
                            ),
                            subtitle: Text(
                              '${_categoryLabel(tx, categoryNames)} · '
                              '${_sourceLabel(tx, sourceNames)} · '
                              '${_dateFormat.format(tx.timestamp)}',
                            ),
                            trailing: Text(
                              '${tx.type == TransactionType.credit ? '+' : '-'}'
                              '${_currency.format(tx.amount)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: tx.type == TransactionType.credit
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                  ),
                            ),
                            onTap: () => _openTransaction(
                              context,
                              tx: tx,
                              sourceNames: sourceNames,
                              categoryNames: categoryNames,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  String _sourceLabel(Transaction tx, Map<String, String> sourceNames) {
    final id = tx.paymentSourceId;
    if (id == null) return 'Unknown account';
    return sourceNames[id] ?? 'Unknown account';
  }

  String _categoryLabel(Transaction tx, Map<String, String> categoryNames) {
    final id = tx.categoryId;
    if (id == null) return 'Uncategorized';
    return categoryNames[id] ?? 'Uncategorized';
  }

  Widget _buildBody(BuildContext context, PeriodSummary summary) {
    final shell = widget.embeddedInShell;

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
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _toggleMode,
              icon: Icon(
                _mode == _OverviewMode.today
                    ? Icons.today_outlined
                    : Icons.date_range_outlined,
              ),
              label: Text(
                _mode == _OverviewMode.today ? 'Today' : 'This Week',
              ),
            ),
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
              label: _mode == _OverviewMode.today ? 'Spent today' : 'Spent this week',
              amount: _currency.format(summary.totalSpend),
              secondaryLabel:
                  summary.totalIncome > 0 ? 'Credits' : null,
              secondaryAmount: summary.totalIncome > 0
                  ? _currency.format(summary.totalIncome)
                  : null,
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          AppSectionHeader(
            title: _transactionSectionTitle,
            icon: Icons.receipt_long_outlined,
          ),
          _buildTransactionList(context),
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
        final body = snapshot.data == null
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context, snapshot.data!);

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(shell ? 'Overview' : 'Dashboard'),
            actions: shell
                ? [
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
                  ]
                : [
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
    return 'No spend yet';
  }

  String get _message {
    if (rawIngestCount > 0 && transactionCount == 0) {
      return '$rawIngestCount SMS stored locally but none became transactions. '
          'Check bank SMS format in Recovery, or add payment sources in Accounts.';
    }
    if (rawIngestCount > 0) {
      return '$rawIngestCount SMS synced but none fall in this window. '
          'Pull down to sync or check Analytics for longer periods.';
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
