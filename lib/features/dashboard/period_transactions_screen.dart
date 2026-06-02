import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_matters/models/category.dart';
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

/// Lists all non-excluded transactions in a dashboard period.
class PeriodTransactionsScreen extends StatelessWidget {
  const PeriodTransactionsScreen({
    super.key,
    required this.dashboardRepository,
    required this.reviewRepository,
    required this.categoryService,
    required this.paymentSourceService,
    required this.periodStart,
    required this.periodEnd,
    required this.periodLabel,
  });

  final DashboardRepository dashboardRepository;
  final ReviewRepository reviewRepository;
  final CategoryService categoryService;
  final PaymentSourceService paymentSourceService;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String periodLabel;

  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  static final _dateFormat = DateFormat('d MMM, h:mm a');

  Future<void> _openTransaction(
    BuildContext context, {
    required Transaction tx,
    required Map<String, String> sourceNames,
    required Map<String, String> categoryNames,
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

  String _categoryLabel(Transaction tx, Map<String, String> categoryNames) {
    final id = tx.categoryId;
    if (id == null) return 'Uncategorized';
    return categoryNames[id] ?? 'Uncategorized';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(periodLabel)),
      body: StreamBuilder<List<PaymentSource>>(
        stream: paymentSourceService.watchAll(),
        builder: (context, sourcesSnapshot) {
          final sourceNames = {
            for (final s in visiblePaymentSources(sourcesSnapshot.data ?? const []))
              s.id: s.name,
          };

          return StreamBuilder<List<Category>>(
            stream: categoryService.watchCategories(),
            builder: (context, categoriesSnapshot) {
              final categoryNames = <String, String>{
                for (final c in categoriesSnapshot.data ?? const [])
                  c.id: c.name,
              };

              return StreamBuilder<List<Transaction>>(
                stream: dashboardRepository.watchPeriodTransactions(
                  start: periodStart,
                  end: periodEnd,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = snapshot.data!;

                  if (items.isEmpty) {
                    return Center(
                      child: AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No transactions',
                        message: 'Nothing recorded for $periodLabel.',
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await dashboardRepository.periodTransactions(
                        start: periodStart,
                        end: periodEnd,
                      );
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.page),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.tight),
                      itemBuilder: (context, index) {
                        final tx = items[index];
                        final isCredit = tx.type == TransactionType.credit;
                        final amountLabel = _currency.format(tx.amount);
                        final prefix = isCredit ? '+' : '-';

                        return Card(
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
                              '$prefix$amountLabel',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isCredit
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
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
