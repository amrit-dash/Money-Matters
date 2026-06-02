import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import '../../services/category_service.dart';
import '../../services/payment_source_service.dart';
import '../accounts/payment_source_widgets.dart';
import '../review/review_repository.dart';
import '../transactions/transaction_detail_screen.dart';
import 'dashboard_repository.dart';

/// Lists matched debit transactions for one category in a dashboard period.
class CategoryDetailScreen extends StatelessWidget {
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

  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  static final _dateFormat = DateFormat('d MMM, h:mm a');

  Future<void> _openTransaction(
    BuildContext context, {
    required Transaction tx,
    required Map<String, String> sourceNames,
  }) async {
    PaymentSource? source;
    final sourceId = tx.paymentSourceId;
    if (sourceId != null) {
      source = await dashboardRepository.paymentSourceById(sourceId);
    }
    if (!context.mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transaction: tx,
          reviewRepository: reviewRepository,
          categoryService: categoryService,
          paymentSourceService: paymentSourceService,
          paymentSourceName: source?.name ?? sourceNames[sourceId],
        ),
      ),
    );
  }

  String _sourceLabel(Transaction tx, Map<String, String> sourceNames) {
    final id = tx.paymentSourceId;
    if (id == null) return 'Unknown account';
    return sourceNames[id] ?? 'Unknown account';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<List<PaymentSource>>(
        stream: paymentSourceService.watchAll(),
        builder: (context, sourcesSnapshot) {
          final sourceNames = {
            for (final s in visiblePaymentSources(sourcesSnapshot.data ?? const []))
              s.id: s.name,
          };

          return StreamBuilder<List<Transaction>>(
            stream: dashboardRepository.watchCategoryTransactions(
              categoryId: categoryId,
              start: periodStart,
              end: periodEnd,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = snapshot.data!;
              final total = items.fold(0.0, (sum, t) => sum + t.amount);

              if (items.isEmpty) {
                return Center(
                  child: AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions',
                    message:
                        'No spend in $title for $periodLabel.',
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await dashboardRepository.categoryTransactions(
                    categoryId: categoryId,
                    start: periodStart,
                    end: periodEnd,
                  );
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.tight),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return HeroSpendCard(
                        label: periodLabel,
                        amount: _currency.format(total),
                        secondaryLabel: 'Transactions',
                        secondaryAmount: '${items.length}',
                        icon: Icons.category_outlined,
                      );
                    }
                    final tx = items[index - 1];
                    return _CategoryTransactionTile(
                      transaction: tx,
                      amountLabel: _currency.format(tx.amount),
                      dateLabel: _dateFormat.format(tx.timestamp),
                      accountLabel: _sourceLabel(tx, sourceNames),
                      onTap: () => _openTransaction(
                        context,
                        tx: tx,
                        sourceNames: sourceNames,
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
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
