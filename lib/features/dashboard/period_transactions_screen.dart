import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';

import '../../core/widgets/app_ui.dart';
import '../../services/app_services.dart';
import '../../core/widgets/transaction_list_filter.dart';
import '../../core/widgets/transaction_list_item.dart';
import '../../services/category_service.dart';
import '../../services/payment_source_service.dart';
import '../accounts/payment_source_widgets.dart';
import '../review/review_repository.dart';
import '../transactions/transaction_detail_screen.dart';
import 'dashboard_repository.dart';

/// Lists all non-excluded transactions in a dashboard period.
class PeriodTransactionsScreen extends StatefulWidget {
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

  @override
  State<PeriodTransactionsScreen> createState() =>
      _PeriodTransactionsScreenState();
}

class _PeriodTransactionsScreenState extends State<PeriodTransactionsScreen> {
  TransactionListFilter _filter = const TransactionListFilter();

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
      source = await widget.dashboardRepository.paymentSourceById(sourceId);
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
      appBar: AppBar(
        title: Text(widget.periodLabel),
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
      body: StreamBuilder<List<PaymentSource>>(
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
                for (final c in categoriesSnapshot.data ?? const [])
                  c.id: c.name,
              };

              return StreamBuilder<List<Transaction>>(
                stream: widget.dashboardRepository.watchPeriodTransactions(
                  start: widget.periodStart,
                  end: widget.periodEnd,
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
                        message:
                            'Nothing recorded for ${widget.periodLabel}.',
                      ),
                    );
                  }

                  final items = _filter.apply(rawItems);
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
                      await AppScope.of(context)
                          .queueDrain
                          .drainIfAuthenticated();
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

                        return TransactionListItem(
                          dateLabel: _dateFormat.format(tx.timestamp),
                          categoryName: _categoryLabel(tx, categoryNames),
                          merchantName:
                              tx.displayMerchant ?? 'Unknown merchant',
                          amountLabel: '$prefix$amountLabel',
                          paymentSourceLabel: _sourceLabel(tx, sourceNames),
                          isCredit: isCredit,
                          onTap: () => _openTransaction(
                            context,
                            tx: tx,
                            sourceNames: sourceNames,
                            categoryNames: categoryNames,
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
