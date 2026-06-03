import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';

import '../../core/widgets/app_ui.dart';
import '../../core/widgets/transaction_list_filter.dart';
import '../../core/widgets/transaction_list_item.dart';
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
  TransactionListFilter _filter = const TransactionListFilter();

  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  static final _dateFormat = DateFormat('d MMM, h:mm a');

  Future<void> _openTransaction(BuildContext context, Transaction tx) async {
    await Navigator.push<bool>(
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          StreamBuilder<List<PaymentSource>>(
            stream: widget.paymentSourceService.watchAll(),
            builder: (context, sourcesSnapshot) {
              return StreamBuilder<List<Category>>(
                stream: widget.categoryService.watchCategories(),
                builder: (context, categoriesSnapshot) {
                  return TransactionListFilterBar(
                    filter: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                    paymentSources: sourcesSnapshot.data ?? const [],
                    categories: categoriesSnapshot.data ?? const [],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Transaction>>(
        stream: widget.dashboardRepository.watchSourceTransactions(
          widget.paymentSourceId,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawItems = snapshot.data!;
          if (rawItems.isEmpty) {
            return Center(
              child: AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No transactions',
                message: widget.paymentSourceId == null
                    ? 'No unmatched transactions right now.'
                    : 'Nothing recorded for this account yet.',
              ),
            );
          }

          final items = _filter.apply(rawItems);
          final total = items
              .where((t) => t.type == TransactionType.debit)
              .fold(0.0, (sum, t) => sum + t.amount);

          if (items.isEmpty) {
            return Center(
              child: AppEmptyState(
                icon: Icons.filter_list_off,
                title: 'No matching transactions',
                message: 'Try clearing or adjusting your filters.',
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await widget.dashboardRepository.sourceTransactions(
                widget.paymentSourceId,
              );
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.tight),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.item),
                    child: Text(
                      '${items.length} transactions · '
                      '${_currency.format(total)} spent',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                }
                final tx = items[index - 1];
                final isCredit = tx.type == TransactionType.credit;
                return TransactionListItem(
                  dateLabel: _dateFormat.format(tx.timestamp),
                  categoryName:
                      widget.categoryService.findById(tx.categoryId)?.name ??
                          'Uncategorized',
                  merchantName: tx.displayMerchant ?? 'Unknown merchant',
                  amountLabel:
                      '${isCredit ? '+' : '-'}${_currency.format(tx.amount)}',
                  paymentSourceLabel: widget.title,
                  isCredit: isCredit,
                  onTap: () => _openTransaction(context, tx),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
