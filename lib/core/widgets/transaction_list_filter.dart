import 'package:flutter/material.dart';
import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';

import '../../features/accounts/payment_source_widgets.dart';
import '../theme/app_theme.dart';

/// How to order transactions in a list view.
enum TransactionListSort {
  latestFirst,
  oldestFirst,
  amountHighToLow,
  amountLowToHigh,
}

/// In-memory filter + sort state for transaction list screens.
class TransactionListFilter {
  const TransactionListFilter({
    this.sort = TransactionListSort.latestFirst,
    this.paymentSourceIds = const {},
    this.categoryIds = const {},
  });

  final TransactionListSort sort;
  final Set<String> paymentSourceIds;
  final Set<String> categoryIds;

  bool get isActive =>
      sort != TransactionListSort.latestFirst ||
      paymentSourceIds.isNotEmpty ||
      categoryIds.isNotEmpty;

  TransactionListFilter copyWith({
    TransactionListSort? sort,
    Set<String>? paymentSourceIds,
    Set<String>? categoryIds,
  }) {
    return TransactionListFilter(
      sort: sort ?? this.sort,
      paymentSourceIds: paymentSourceIds ?? this.paymentSourceIds,
      categoryIds: categoryIds ?? this.categoryIds,
    );
  }

  List<Transaction> apply(List<Transaction> items) {
    var result = items.toList();

    if (paymentSourceIds.isNotEmpty) {
      result = result
          .where(
            (t) =>
                t.paymentSourceId != null &&
                paymentSourceIds.contains(t.paymentSourceId),
          )
          .toList();
    }

    if (categoryIds.isNotEmpty) {
      result = result
          .where(
            (t) =>
                t.categoryId != null && categoryIds.contains(t.categoryId),
          )
          .toList();
    }

    result.sort((a, b) {
      switch (sort) {
        case TransactionListSort.latestFirst:
          return b.timestamp.compareTo(a.timestamp);
        case TransactionListSort.oldestFirst:
          return a.timestamp.compareTo(b.timestamp);
        case TransactionListSort.amountHighToLow:
          final byAmount = b.amount.compareTo(a.amount);
          return byAmount != 0
              ? byAmount
              : b.timestamp.compareTo(a.timestamp);
        case TransactionListSort.amountLowToHigh:
          final byAmount = a.amount.compareTo(b.amount);
          return byAmount != 0
              ? byAmount
              : b.timestamp.compareTo(a.timestamp);
      }
    });

    return result;
  }
}

/// App bar action: opens filter sheet, or clears when a filter is active.
class TransactionListFilterBar extends StatelessWidget {
  const TransactionListFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.paymentSources,
    required this.categories,
  });

  final TransactionListFilter filter;
  final ValueChanged<TransactionListFilter> onChanged;
  final List<PaymentSource> paymentSources;
  final List<Category> categories;

  Future<void> _onPressed(BuildContext context) async {
    if (filter.isActive) {
      onChanged(const TransactionListFilter());
      return;
    }

    final updated = await showTransactionListFilterSheet(
      context,
      filter: filter,
      paymentSources: paymentSources,
      categories: categories,
    );
    if (updated != null) onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        filter.isActive
            ? Icons.filter_list_off
            : Icons.filter_list_outlined,
      ),
      tooltip: filter.isActive ? 'Clear filters' : 'Filter transactions',
      onPressed: () => _onPressed(context),
    );
  }
}

/// Modal bottom sheet for configuring [TransactionListFilter].
Future<TransactionListFilter?> showTransactionListFilterSheet(
  BuildContext context, {
  required TransactionListFilter filter,
  required List<PaymentSource> paymentSources,
  required List<Category> categories,
}) {
  return showModalBottomSheet<TransactionListFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _TransactionListFilterSheet(
      initial: filter,
      paymentSources: visiblePaymentSources(paymentSources),
      categories: categories,
    ),
  );
}

class _TransactionListFilterSheet extends StatefulWidget {
  const _TransactionListFilterSheet({
    required this.initial,
    required this.paymentSources,
    required this.categories,
  });

  final TransactionListFilter initial;
  final List<PaymentSource> paymentSources;
  final List<Category> categories;

  @override
  State<_TransactionListFilterSheet> createState() =>
      _TransactionListFilterSheetState();
}

class _TransactionListFilterSheetState extends State<_TransactionListFilterSheet> {
  late TransactionListSort _sort;
  late Set<String> _paymentSourceIds;
  late Set<String> _categoryIds;

  @override
  void initState() {
    super.initState();
    _sort = widget.initial.sort;
    _paymentSourceIds = Set.of(widget.initial.paymentSourceIds);
    _categoryIds = Set.of(widget.initial.categoryIds);
  }

  void _apply() {
    Navigator.pop(
      context,
      TransactionListFilter(
        sort: _sort,
        paymentSourceIds: _paymentSourceIds,
        categoryIds: _categoryIds,
      ),
    );
  }

  void _reset() {
    setState(() {
      _sort = TransactionListSort.latestFirst;
      _paymentSourceIds = {};
      _categoryIds = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.tight,
                ),
                child: Text(
                  'Filter transactions',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: Text(
                  'Sort by',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              ...TransactionListSort.values.map((option) {
                final selected = _sort == option;
                final label = switch (option) {
                  TransactionListSort.latestFirst => 'Latest first',
                  TransactionListSort.oldestFirst => 'Oldest first',
                  TransactionListSort.amountHighToLow => 'Amount high to low',
                  TransactionListSort.amountLowToHigh => 'Amount low to high',
                };
                return ListTile(
                  title: Text(label),
                  trailing: selected
                      ? Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        )
                      : Icon(
                          Icons.circle_outlined,
                          color: theme.colorScheme.outline,
                        ),
                  onTap: () => setState(() => _sort = option),
                );
              }),
              if (widget.paymentSources.isNotEmpty) ...[
                const Divider(height: 24),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  child: Text(
                    'Payment method',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                ...widget.paymentSources.map((source) {
                  final label = source.last4 != null
                      ? '${source.name} ···· ${source.last4}'
                      : source.name;
                  return CheckboxListTile(
                    title: Text(label),
                    value: _paymentSourceIds.contains(source.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _paymentSourceIds.add(source.id);
                        } else {
                          _paymentSourceIds.remove(source.id);
                        }
                      });
                    },
                  );
                }),
              ],
              if (widget.categories.isNotEmpty) ...[
                const Divider(height: 24),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  child: Text(
                    'Category',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                ...widget.categories.map((category) {
                  return CheckboxListTile(
                    title: Text(category.name),
                    value: _categoryIds.contains(category.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _categoryIds.add(category.id);
                        } else {
                          _categoryIds.remove(category.id);
                        }
                      });
                    },
                  );
                }),
              ],
              Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _reset,
                      child: const Text('Reset'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _apply,
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
