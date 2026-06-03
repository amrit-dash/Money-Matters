import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_matters/models/transaction.dart';

import '../../core/widgets/app_ui.dart';
import '../../core/widgets/transaction_list_filter.dart';
import '../../core/widgets/transaction_list_item.dart';
import '../../services/app_services.dart';
import 'classify_screen.dart';
import 'review_repository.dart';

/// "Needs your input" inbox — the in-app fallback for classification that works
/// without push notifications (no paid Apple account required).
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.repository,
    this.embeddedInShell = false,
    this.onListChanged,
  });

  final ReviewRepository repository;
  final bool embeddedInShell;
  final VoidCallback? onListChanged;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('d MMM, h:mm a');
  TransactionListFilter _filter = const TransactionListFilter();

  Future<void> _openClassify(Transaction tx) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => ClassifyScreen(
          repository: widget.repository,
          paymentSourceService: AppScope.of(ctx).paymentSourceService,
          transaction: tx,
        ),
      ),
    );
    if (changed == true) widget.onListChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    const inboxPadding = EdgeInsets.symmetric(horizontal: 28);

    return StreamBuilder<List<Transaction>>(
      stream: widget.repository.watchFlaggedTransactions(),
      builder: (context, snapshot) {
        final rawItems = snapshot.data;
        final hasItems = rawItems != null && rawItems.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !widget.embeddedInShell,
            title: Text(widget.embeddedInShell ? 'Inbox' : 'Needs your input'),
            actions: [
              if (hasItems)
                Builder(
                  builder: (context) {
                    final services = AppScope.of(context);
                    return StreamBuilder(
                      stream: services.paymentSourceService.watchAll(),
                      builder: (context, sourcesSnapshot) {
                        return StreamBuilder(
                          stream: services.categoryService.watchCategories(),
                          builder: (context, categoriesSnapshot) {
                            return TransactionListFilterBar(
                              filter: _filter,
                              onChanged: (f) => setState(() => _filter = f),
                              paymentSources:
                                  sourcesSnapshot.data ?? const [],
                              categories:
                                  categoriesSnapshot.data ?? const [],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
            ],
          ),
          body: !snapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : rawItems!.isEmpty
                  ? Center(
                      child: Padding(
                        padding: inboxPadding,
                        child: const AppEmptyState(
                          icon: Icons.check_circle_outline,
                          title: 'All clear',
                          message:
                              'Nothing needs you right now. When we are unsure '
                              'about a category or account, it will show up here '
                              'for a quick tap.',
                        ),
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final items = _filter.apply(rawItems);

                        if (items.isEmpty) {
                          return Padding(
                            padding: inboxPadding,
                            child: const AppEmptyState(
                              icon: Icons.filter_list_off,
                              title: 'No matching items',
                              message:
                                  'Try clearing or adjusting your filters.',
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            await widget.repository.flaggedTransactions();
                          },
                          child: ListView.separated(
                            padding: inboxPadding.copyWith(
                              top: AppSpacing.page,
                              bottom: AppSpacing.page,
                            ),
                            itemCount: items.length + 1,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: AppSpacing.tight),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return AppSectionHeader(
                                  title: 'To classify (${items.length})',
                                  subtitle:
                                      'Tap a row to pick a category, notes, or items',
                                  icon: Icons.label_outline,
                                );
                              }
                              final tx = items[index - 1];
                              final categoryService =
                                  AppScope.of(context).categoryService;
                              final categoryName =
                                  categoryService.findById(tx.categoryId)?.name ??
                                      'Uncategorized';
                              final isCredit = tx.type == TransactionType.credit;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TransactionListItem(
                                    dateLabel: _dateFormat.format(tx.timestamp),
                                    categoryName: categoryName,
                                    merchantName:
                                        tx.displayMerchant ?? 'Unknown merchant',
                                    amountLabel:
                                        '${isCredit ? '+' : '-'}${_currency.format(tx.amount)}',
                                    paymentSourceLabel: tx.unmatched
                                        ? 'No linked account'
                                        : (tx.paymentSourceId ?? 'Account'),
                                    isCredit: isCredit,
                                    onTap: () => _openClassify(tx),
                                  ),
                                  if (_flagLabels(tx).isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.tight),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: _flagLabels(tx)
                                          .map(
                                            (f) => AppStatusChip(
                                              label: f,
                                              tone: AppStatTone.warning,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }
}

List<String> _flagLabels(Transaction tx) => [
      if (tx.needsClassification) 'Needs category',
      if (tx.ambiguous) 'Ambiguous',
      if (tx.unmatched) 'Unmatched',
    ];
