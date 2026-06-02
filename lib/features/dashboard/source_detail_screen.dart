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
class SourceDetailScreen extends StatelessWidget {
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

  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  static final _dateFormat = DateFormat('d MMM, h:mm a');

  Future<void> _openTransaction(BuildContext context, Transaction tx) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transaction: tx,
          reviewRepository: reviewRepository,
          categoryService: categoryService,
          paymentSourceService: paymentSourceService,
          paymentSourceName: source?.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<List<Transaction>>(
        stream: dashboardRepository.watchSourceTransactions(paymentSourceId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;
          final total = items
              .where((t) => t.type == TransactionType.debit)
              .fold(0.0, (sum, t) => sum + t.amount);

          if (items.isEmpty) {
            return Center(
              child: AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No transactions',
                message: paymentSourceId == null
                    ? 'No unmatched transactions right now.'
                    : 'Nothing recorded for this account yet.',
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await dashboardRepository.sourceTransactions(paymentSourceId);
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
                return _TransactionTile(
                  transaction: tx,
                  amountLabel: _currency.format(tx.amount),
                  dateLabel: _dateFormat.format(tx.timestamp),
                  categoryName:
                      categoryService.findById(tx.categoryId)?.name ??
                          'Uncategorized',
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
