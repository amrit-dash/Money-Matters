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
import '../accounts/payment_source_widgets.dart';
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
  TransactionListFilter _filter = const TransactionListFilter();

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
      body: StreamBuilder<List<PaymentSource>>(
        stream: widget.paymentSourceService.watchAll(),
        builder: (context, sourcesSnapshot) {
          final sourceNames = {
            for (final s
                in visiblePaymentSources(sourcesSnapshot.data ?? const []))
              s.id: s.name,
          };

          return StreamBuilder<List<Transaction>>(
            stream: widget.dashboardRepository.watchCategoryTransactions(
              categoryId: widget.categoryId,
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
                        'No spend in ${widget.title} for ${widget.periodLabel}.',
                  ),
                );
              }

              final items = _filter.apply(rawItems);
              final total = items.fold(0.0, (sum, t) => sum + t.amount);

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
                  await widget.dashboardRepository.categoryTransactions(
                    categoryId: widget.categoryId,
                    start: widget.periodStart,
                    end: widget.periodEnd,
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
                        label: widget.periodLabel,
                        amount: _currency.format(total),
                        secondaryLabel: 'Transactions',
                        secondaryAmount: '${items.length}',
                        icon: Icons.category_outlined,
                      );
                    }
                    final tx = items[index - 1];
                    return TransactionListItem(
                      dateLabel: _dateFormat.format(tx.timestamp),
                      categoryName: widget.title,
                      merchantName: tx.displayMerchant ?? 'Unknown merchant',
                      amountLabel: '-${_currency.format(tx.amount)}',
                      paymentSourceLabel: _sourceLabel(tx, sourceNames),
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
