import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';

import '../../app_router.dart';
import '../../core/dashboard/dashboard_preferences_store.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/transaction_list_filter.dart';
import '../../core/widgets/transaction_list_item.dart';
import '../../core/widgets/dashboard_charts.dart';
import '../../ingest/ingest_queue_drain.dart';
import '../../ingest/ingest_repository.dart';
import '../../services/category_service.dart';
import '../accounts/payment_source_widgets.dart';
import '../recovery/recovery_repository.dart';
import '../review/review_repository.dart';
import '../../services/payment_source_service.dart';
import '../transactions/transaction_detail_screen.dart';
import 'dashboard_repository.dart';
import 'overview_spend_calendar.dart';

enum _OverviewLayout { calendar, list }

enum _ListRangeFilter { today, pastThreeDays, pastSevenDays }

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
  final _layoutPrefs = DashboardPreferencesStore();
  _OverviewLayout _layout = _OverviewLayout.calendar;
  _ListRangeFilter _listRange = _ListRangeFilter.today;
  TransactionListFilter _listFilter = const TransactionListFilter();
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selectedCalendarDate;

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
  static final _selectedDateFormat = DateFormat('d MMMM yyyy');

  DateTime get _todayEnd {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  DateTime get _listRangeStart {
    final now = DateTime.now();
    final endDay = DateTime(now.year, now.month, now.day);
    return switch (_listRange) {
      _ListRangeFilter.today => endDay,
      _ListRangeFilter.pastThreeDays => endDay.subtract(const Duration(days: 2)),
      _ListRangeFilter.pastSevenDays => endDay.subtract(const Duration(days: 6)),
    };
  }

  String get _listRangeLabel => switch (_listRange) {
        _ListRangeFilter.today => 'Today',
        _ListRangeFilter.pastThreeDays => 'Past 3 days',
        _ListRangeFilter.pastSevenDays => 'Past 7 days',
      };

  String get _spentLabel => switch (_listRange) {
        _ListRangeFilter.today => 'Spent today',
        _ListRangeFilter.pastThreeDays => 'Spent in past 3 days',
        _ListRangeFilter.pastSevenDays => 'Spent in past 7 days',
      };

  String get _transactionSectionTitle => switch (_listRange) {
        _ListRangeFilter.today => 'Today\'s transactions',
        _ListRangeFilter.pastThreeDays => 'Past 3 days',
        _ListRangeFilter.pastSevenDays => 'Past 7 days',
      };

  Stream<PeriodSummary> get _listSummaryStream =>
      widget.repository.watchRangeSummary(
        start: _listRangeStart,
        end: _todayEnd,
        label: _listRangeLabel,
      );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedCalendarDate = DateTime(now.year, now.month, now.day);
    _loadLayoutPreference();
    _drainSubscription = widget.queueDrain?.onDrained.listen((_) {
      if (mounted) _loadAuxiliaryData();
    });
    _loadAuxiliaryData();
  }

  Future<void> _loadLayoutPreference() async {
    final saved = await _layoutPrefs.loadLayout();
    if (!mounted) return;
    setState(() {
      _layout = saved == 'list'
          ? _OverviewLayout.list
          : _OverviewLayout.calendar;
    });
  }

  @override
  void dispose() {
    _syncMessageTimer?.cancel();
    _pipelineTimer?.cancel();
    _drainSubscription?.cancel();
    super.dispose();
  }

  void _toggleLayout() {
    final next = _layout == _OverviewLayout.calendar
        ? _OverviewLayout.list
        : _OverviewLayout.calendar;
    setState(() => _layout = next);
    _layoutPrefs.saveLayout(
      next == _OverviewLayout.list ? 'list' : 'calendar',
    );
  }

  void _selectListRange(_ListRangeFilter range) {
    if (_listRange == range) return;
    setState(() => _listRange = range);
  }

  void _shiftCalendarMonth(int direction) {
    setState(() {
      _calendarMonth = DateTime(
        _calendarMonth.year,
        _calendarMonth.month + direction,
      );
    });
  }

  void _selectCalendarDate(DateTime day) {
    setState(() => _selectedCalendarDate = day);
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

  DateTime _dayStart(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  DateTime _dayEnd(DateTime day) =>
      DateTime(day.year, day.month, day.day, 23, 59, 59, 999);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isSelectedDateToday(DateTime day) {
    final now = DateTime.now();
    return _isSameDay(day, DateTime(now.year, now.month, now.day));
  }

  String _calendarSpentHeading(DateTime selected) =>
      _isSelectedDateToday(selected)
          ? 'Spent today'
          : 'Spent on ${_selectedDateFormat.format(selected)}';

  Widget _buildEmptyDayBanner(BuildContext context) {
    return Card(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No transactions recorded on this day.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList({
    required DateTime start,
    required DateTime end,
    required String emptyMessage,
    TransactionListFilter? filter,
  }) {
    final listFilter = filter ?? const TransactionListFilter();
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
                start: start,
                end: end,
              ),
              builder: (context, snapshot) {
                final rawItems = snapshot.data;
                if (rawItems == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (rawItems.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.item),
                    child: Text(
                      emptyMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }

                final items = listFilter.apply(rawItems);
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.item),
                    child: Text(
                      'No transactions match the current filters.',
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
                        child: TransactionListItem(
                          dateLabel: _dateFormat.format(tx.timestamp),
                          categoryName: _categoryLabel(tx, categoryNames),
                          merchantName:
                              tx.displayMerchant ?? 'Unknown merchant',
                          amountLabel:
                              '${tx.type == TransactionType.credit ? '+' : '-'}'
                              '${_currency.format(tx.amount)}',
                          paymentSourceLabel:
                              _sourceLabel(tx, sourceNames),
                          isCredit: tx.type == TransactionType.credit,
                          onTap: () => _openTransaction(
                            context,
                            tx: tx,
                            sourceNames: sourceNames,
                            categoryNames: categoryNames,
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

  Widget _buildSyncAndPipelineBanner() {
    return Column(
      children: [
        if (_syncMessage != null) ...[
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
          const SizedBox(height: AppSpacing.item),
        ],
        if (_showPipelineSummary) ...[
          _PipelineSummary(
            synced: _rawIngestCount,
            parsed: _transactionCount,
            onOpenRecovery: () =>
                Navigator.pushNamed(context, AppRoutes.recovery),
          ),
          const SizedBox(height: AppSpacing.item),
        ],
      ],
    );
  }

  Widget _buildListRangeFilters() {
    return Wrap(
      spacing: AppSpacing.tight,
      runSpacing: AppSpacing.tight,
      children: [
        for (final range in _ListRangeFilter.values)
          FilterChip(
            label: Text(switch (range) {
              _ListRangeFilter.today => 'Today',
              _ListRangeFilter.pastThreeDays => 'Past 3 days',
              _ListRangeFilter.pastSevenDays => 'Past 7 days',
            }),
            selected: _listRange == range,
            onSelected: (_) => _selectListRange(range),
          ),
      ],
    );
  }

  Widget _buildListBody(PeriodSummary summary) {
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
          _buildListRangeFilters(),
          const SizedBox(height: AppSpacing.item),
          _buildSyncAndPipelineBanner(),
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
              label: _spentLabel,
              amount: _currency.format(summary.totalSpend),
              secondaryLabel: summary.totalIncome > 0 ? 'Credits' : null,
              secondaryAmount: summary.totalIncome > 0
                  ? _currency.format(summary.totalIncome)
                  : null,
            ),
          ],
          if (summary.breakdown.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.section),
            CategorySpendBarChart(
              breakdown: summary.breakdown,
              totalSpend: summary.totalSpend,
              maxBars: 10,
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          AppSectionHeader(
            title: _transactionSectionTitle,
            icon: Icons.receipt_long_outlined,
          ),
          _buildTransactionList(
            start: _listRangeStart,
            end: _todayEnd,
            emptyMessage: _modeEmptyMessage(),
            filter: _listFilter,
          ),
        ],
      ),
    );
  }

  String _modeEmptyMessage() => switch (_listRange) {
        _ListRangeFilter.today => 'No transactions recorded today.',
        _ListRangeFilter.pastThreeDays =>
          'No transactions in the past three days.',
        _ListRangeFilter.pastSevenDays =>
          'No transactions in the past seven days.',
      };

  Widget _buildCalendarBody() {
    final shell = widget.embeddedInShell;
    final selected = _selectedCalendarDate;

    return RefreshIndicator(
      onRefresh: _syncQueue,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final calendarHeight = (constraints.maxHeight * 0.62)
              .clamp(320.0, constraints.maxHeight - 120);

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.page,
                  AppSpacing.page,
                  0,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
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
                    _buildSyncAndPipelineBanner(),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: calendarHeight,
                    child: StreamBuilder<Map<DateTime, double>>(
                      stream: widget.repository
                          .watchDailySpendForMonth(_calendarMonth),
                      builder: (context, snapshot) {
                        final dailySpend = snapshot.data ?? const {};
                        return OverviewSpendCalendar(
                          month: _calendarMonth,
                          dailySpend: dailySpend,
                          selectedDate: selected,
                          onDateSelected: _selectCalendarDate,
                          onPreviousMonth: () => _shiftCalendarMonth(-1),
                          onNextMonth: () => _shiftCalendarMonth(1),
                        );
                      },
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.page),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    StreamBuilder<PeriodSummary>(
                      stream: widget.repository.watchDailySummary(
                        anchor: selected,
                      ),
                      builder: (context, summarySnapshot) {
                        final summary = summarySnapshot.data;
                        if (summary == null) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final isEmpty = _isEmpty(summary);

                        if (isEmpty) {
                          return _buildEmptyDayBanner(context);
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppSectionHeader(
                              title: _calendarSpentHeading(selected),
                              icon: Icons.calendar_today_outlined,
                            ),
                            HeroSpendCard(
                              label: 'Total spend',
                              amount: _currency.format(summary.totalSpend),
                              secondaryLabel: summary.totalIncome > 0
                                  ? 'Credits'
                                  : null,
                              secondaryAmount: summary.totalIncome > 0
                                  ? _currency.format(summary.totalIncome)
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.section),
                            _buildTransactionList(
                              start: _dayStart(selected),
                              end: _dayEnd(selected),
                              emptyMessage: 'No transactions on this day.',
                            ),
                          ],
                        );
                      },
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.embeddedInShell;
    final isList = _layout == _OverviewLayout.list;

    final scaffold = isList
        ? StreamBuilder<PeriodSummary>(
            stream: _listSummaryStream,
            builder: (context, snapshot) {
              final body = snapshot.data == null
                  ? const Center(child: CircularProgressIndicator())
                  : _buildListBody(snapshot.data!);
              return _buildScaffold(context, shell: shell, body: body);
            },
          )
        : _buildScaffold(
            context,
            shell: shell,
            body: _buildCalendarBody(),
          );

    if (shell) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }

  Widget _buildScaffold(
    BuildContext context, {
    required bool shell,
    required Widget body,
  }) {
    final isList = _layout == _OverviewLayout.list;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(shell ? 'Overview' : 'Dashboard'),
        actions: shell
            ? [
                if (isList)
                  _OverviewListFilterAction(
                    filter: _listFilter,
                    onChanged: (f) => setState(() => _listFilter = f),
                    paymentSourceService: widget.paymentSourceService,
                    categoryService: widget.categoryService,
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Icon(
                      isList
                          ? Icons.calendar_month_outlined
                          : Icons.view_list_outlined,
                    ),
                    tooltip: isList ? 'Calendar view' : 'List view',
                    onPressed: _toggleLayout,
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
  }
}

class _OverviewListFilterAction extends StatelessWidget {
  const _OverviewListFilterAction({
    required this.filter,
    required this.onChanged,
    required this.paymentSourceService,
    required this.categoryService,
  });

  final TransactionListFilter filter;
  final ValueChanged<TransactionListFilter> onChanged;
  final PaymentSourceService paymentSourceService;
  final CategoryService categoryService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PaymentSource>>(
      stream: paymentSourceService.watchAll(),
      builder: (context, sourcesSnapshot) {
        return StreamBuilder<List<Category>>(
          stream: categoryService.watchCategories(),
          builder: (context, categoriesSnapshot) {
            return TransactionListFilterBar(
              filter: filter,
              onChanged: onChanged,
              paymentSources: sourcesSnapshot.data ?? const [],
              categories: categoriesSnapshot.data ?? const [],
            );
          },
        );
      },
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
