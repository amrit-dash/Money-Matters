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

/// Lists every transaction for one payment source (or the unmatched bucket).
class SourceDetailScreen extends StatefulWidget {
  const SourceDetailScreen({
    super.key,
    required this.dashboardRepository,
    required this.reviewRepository,
    required this.categoryService,
    required this.paymentSourceService,
    required this.paymentSourceId,
    required this.title,
    this.source,
  });

  final DashboardRepository dashboardRepository;
  final ReviewRepository reviewRepository;
  final CategoryService categoryService;
  final PaymentSourceService paymentSourceService;

  /// Null means the unmatched bucket.
  final String? paymentSourceId;
  final String title;
  final PaymentSource? source;

  @override
  State<SourceDetailScreen> createState() => _SourceDetailScreenState();
}

class _SourceDetailScreenState extends State<SourceDetailScreen> {
  List<Transaction> _items = [];
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
    final items =
        await widget.dashboardRepository.sourceTransactions(widget.paymentSourceId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  double get _total => _items
      .where((t) => t.type == TransactionType.debit)
      .fold(0.0, (sum, t) => sum + t.amount);

  Future<void> _openTransaction(Transaction tx) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transaction: tx,
          reviewRepository: widget.reviewRepository,
          categoryService: widget.categoryService,
          paymentSourceService: widget.paymentSourceService,
          paymentSourceName: widget.source?.name,
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
                    message: widget.paymentSourceId == null
                        ? 'No unmatched transactions right now.'
                        : 'Nothing recorded for this account yet.',
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
                          child: Text(
                            '${_items.length} transactions · '
                            '${_currency.format(_total)} spent',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        );
                      }
                      final tx = _items[index - 1];
                      return _TransactionTile(
                        transaction: tx,
                        amountLabel: _currency.format(tx.amount),
                        dateLabel: _dateFormat.format(tx.timestamp),
                        categoryName: widget.categoryService
                                .findById(tx.categoryId)
                                ?.name ??
                            'Uncategorized',
                        onTap: () => _openTransaction(tx),
                      );
                    },
                  ),
                ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.amountLabel,
    required this.dateLabel,
    required this.categoryName,
    required this.onTap,
  });

  final Transaction transaction;
  final String amountLabel;
  final String dateLabel;
  final String categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCredit = transaction.type == TransactionType.credit;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(transaction.displayMerchant ?? 'Unknown merchant'),
        subtitle: Text('$categoryName · $dateLabel'),
        trailing: Text(
          '${isCredit ? '+' : '-'}$amountLabel',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isCredit ? scheme.primary : scheme.onSurface,
              ),
        ),
        onTap: onTap,
      ),
    );
  }
}
