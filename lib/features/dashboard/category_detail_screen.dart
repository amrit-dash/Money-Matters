import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import '../../services/category_service.dart';
import '../../services/payment_source_service.dart';
import '../review/review_repository.dart';
import '../transactions/transaction_detail_screen.dart';
import 'dashboard_repository.dart';

/// Lists matched debit transactions for one category in a dashboard period.
class CategoryDetailScreen extends StatefulWidget {
  const CategoryDetailScreen({
    super.key,
    required this.dashboardRepository,
    required this.reviewRepository,
    required this.categoryService,
    required this.paymentSourceService,
    required this.categoryId,
    required this.title,
    required this.periodStart,
    required this.periodEnd,
    required this.periodLabel,
  });

  final DashboardRepository dashboardRepository;
  final ReviewRepository reviewRepository;
  final CategoryService categoryService;
  final PaymentSourceService paymentSourceService;

  final String categoryId;
  final String title;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String periodLabel;

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  List<Transaction> _items = [];
  Map<String, String> _sourceNames = {};
  bool _loading = true;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('d MMM, h:mm a');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await widget.dashboardRepository.categoryTransactions(
      categoryId: widget.categoryId,
      start: widget.periodStart,
      end: widget.periodEnd,
    );
    final sources = await widget.paymentSourceService.loadAll();
    if (!mounted) return;
    setState(() {
      _items = items;
      _sourceNames = {for (final s in sources) s.id: s.name};
      _loading = false;
    });
  }

  double get _total =>
      _items.fold(0.0, (sum, t) => sum + t.amount);

  String _sourceLabel(Transaction tx) {
    final id = tx.paymentSourceId;
    if (id == null) return 'Unknown account';
    return _sourceNames[id] ?? 'Unknown account';
  }

  Future<void> _openTransaction(Transaction tx) async {
    PaymentSource? source;
    final sourceId = tx.paymentSourceId;
    if (sourceId != null) {
      source = await widget.dashboardRepository.paymentSourceById(sourceId);
    }
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transaction: tx,
          reviewRepository: widget.reviewRepository,
          categoryService: widget.categoryService,
          paymentSourceService: widget.paymentSourceService,
          paymentSourceName: source?.name,
        ),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions',
                    message:
                        'No spend in ${widget.title} for ${widget.periodLabel}.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    itemCount: _items.length + 1,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.tight),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.item),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.periodLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_items.length} transactions · '
                                '${_currency.format(_total)} spent',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        );
                      }
                      final tx = _items[index - 1];
                      return _CategoryTransactionTile(
                        transaction: tx,
                        amountLabel: _currency.format(tx.amount),
                        dateLabel: _dateFormat.format(tx.timestamp),
                        accountLabel: _sourceLabel(tx),
                        onTap: () => _openTransaction(tx),
                      );
                    },
                  ),
                ),
    );
  }
}

class _CategoryTransactionTile extends StatelessWidget {
  const _CategoryTransactionTile({
    required this.transaction,
    required this.amountLabel,
    required this.dateLabel,
    required this.accountLabel,
    required this.onTap,
  });

  final Transaction transaction;
  final String amountLabel;
  final String dateLabel;
  final String accountLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(transaction.displayMerchant ?? 'Unknown merchant'),
        subtitle: Text('$accountLabel · $dateLabel'),
        trailing: Text(
          '-$amountLabel',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
        ),
        onTap: onTap,
      ),
    );
  }
}
