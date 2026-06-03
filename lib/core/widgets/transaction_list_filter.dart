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

/// Opens the filter popup; returns `null` when dismissed without applying.
class TransactionListFilterBar extends StatelessWidget {
  const TransactionListFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.paymentSources,
    required this.categories,
    this.iconSize = 24,
  });

  final TransactionListFilter filter;
  final ValueChanged<TransactionListFilter> onChanged;
  final List<PaymentSource> paymentSources;
  final List<Category> categories;
  final double iconSize;

  Future<void> _onPressed(BuildContext context) async {
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: Icon(
          Icons.filter_list_outlined,
          size: iconSize,
          color: filter.isActive ? theme.colorScheme.primary : null,
        ),
        tooltip: filter.isActive ? 'Edit filters' : 'Filter transactions',
        onPressed: () => _onPressed(context),
      ),
    );
  }
}

/// Scrollable filter dialog (not full-screen).
Future<TransactionListFilter?> showTransactionListFilterSheet(
  BuildContext context, {
  required TransactionListFilter filter,
  required List<PaymentSource> paymentSources,
  required List<Category> categories,
}) {
  return showDialog<TransactionListFilter>(
    context: context,
    barrierDismissible: true,
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

enum _SortAxis { date, amount }

class _TransactionListFilterSheetState extends State<_TransactionListFilterSheet> {
  late TransactionListSort _sort;
  late Set<String> _paymentSourceIds;
  late Set<String> _categoryIds;
  late _SortAxis _sortAxis;
  late bool _sortDescending;

  @override
  void initState() {
    super.initState();
    _sort = widget.initial.sort;
    _paymentSourceIds = Set.of(widget.initial.paymentSourceIds);
    _categoryIds = Set.of(widget.initial.categoryIds);
    _initSortControls();
  }

  void _initSortControls() {
    switch (_sort) {
      case TransactionListSort.latestFirst:
        _sortAxis = _SortAxis.date;
        _sortDescending = true;
      case TransactionListSort.oldestFirst:
        _sortAxis = _SortAxis.date;
        _sortDescending = false;
      case TransactionListSort.amountHighToLow:
        _sortAxis = _SortAxis.amount;
        _sortDescending = true;
      case TransactionListSort.amountLowToHigh:
        _sortAxis = _SortAxis.amount;
        _sortDescending = false;
    }
  }

  void _syncSortFromControls() {
    _sort = switch (_sortAxis) {
      _SortAxis.date =>
        _sortDescending
            ? TransactionListSort.latestFirst
            : TransactionListSort.oldestFirst,
      _SortAxis.amount =>
        _sortDescending
            ? TransactionListSort.amountHighToLow
            : TransactionListSort.amountLowToHigh,
    };
  }

  void _apply() {
    _syncSortFromControls();
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
      _sortAxis = _SortAxis.date;
      _sortDescending = true;
    });
  }

  void _closeWithoutApply() => Navigator.pop(context);

  void _setSortAxis(_SortAxis axis) {
    setState(() {
      _sortAxis = axis;
      _syncSortFromControls();
    });
  }

  void _setSortDescending(bool value) {
    setState(() {
      _sortDescending = value;
      _syncSortFromControls();
    });
  }

  void _togglePaymentSource(String id, bool? checked) {
    setState(() {
      if (checked == true) {
        _paymentSourceIds.add(id);
      } else {
        _paymentSourceIds.remove(id);
      }
    });
  }

  String _paymentSourceLabel(PaymentSource source) {
    return source.last4 != null
        ? '${source.name} ···· ${source.last4}'
        : source.name;
  }

  Widget _buildPaymentMethodSection(ThemeData theme) {
    final banks =
        widget.paymentSources.where((s) => s.type == PaymentSourceType.bank);
    final cards =
        widget.paymentSources.where((s) => s.type == PaymentSourceType.card);

    Widget section(String title, Iterable<PaymentSource> sources) {
      final list = sources.toList();
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.tight,
              AppSpacing.page,
              0,
            ),
            child: Text(title, style: theme.textTheme.labelMedium),
          ),
          ...list.map(
            (source) => CheckboxListTile(
              dense: true,
              title: Text(_paymentSourceLabel(source)),
              value: _paymentSourceIds.contains(source.id),
              onChanged: (checked) => _togglePaymentSource(source.id, checked),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section('Banks', banks),
        section('Cards', cards),
      ],
    );
  }

  Widget _buildCategorySection(ThemeData theme) {
    if (widget.categories.isEmpty) return const SizedBox.shrink();

    final selectedCount = _categoryIds.length;
    String summary;
    if (selectedCount == 0) {
      summary = 'All categories';
    } else if (selectedCount == 1) {
      final id = _categoryIds.first;
      final match =
          widget.categories.where((c) => c.id == id).map((c) => c.name);
      summary = match.isEmpty ? '1 category' : match.first;
    } else {
      summary = '$selectedCount categories selected';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Text('Category', style: theme.textTheme.labelLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.tight,
            AppSpacing.page,
            0,
          ),
          child: OutlinedButton(
            onPressed: () async {
              final picked = await showDialog<Set<String>>(
                context: context,
                builder: (ctx) {
                  var draft = Set<String>.from(_categoryIds);
                  return AlertDialog(
                    title: const Text('Categories'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: StatefulBuilder(
                        builder: (context, setDialogState) {
                          return SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: widget.categories
                                  .map(
                                    (category) => CheckboxListTile(
                                      title: Text(category.name),
                                      value: draft.contains(category.id),
                                      onChanged: (checked) {
                                        setDialogState(() {
                                          if (checked == true) {
                                            draft.add(category.id);
                                          } else {
                                            draft.remove(category.id);
                                          }
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          );
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, draft),
                        child: const Text('Done'),
                      ),
                    ],
                  );
                },
              );
              if (picked != null) {
                setState(() => _categoryIds = picked);
              }
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(summary),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        'Filter transactions',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: _closeWithoutApply,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.page,
                      ),
                      child: Text('Sort by', style: theme.textTheme.labelLarge),
                    ),
                    ListTile(
                      title: const Text('Sort by date'),
                      subtitle: Text(
                        _sortAxis == _SortAxis.date
                            ? (_sortDescending
                                ? 'Latest first'
                                : 'Oldest first')
                            : 'Newest ↔ oldest',
                      ),
                      selected: _sortAxis == _SortAxis.date,
                      trailing: Switch(
                        value: _sortAxis == _SortAxis.date && _sortDescending,
                        onChanged: (value) {
                          _setSortAxis(_SortAxis.date);
                          _setSortDescending(value);
                        },
                      ),
                      onTap: () => _setSortAxis(_SortAxis.date),
                    ),
                    ListTile(
                      title: const Text('Sort by amount'),
                      subtitle: Text(
                        _sortAxis == _SortAxis.amount
                            ? (_sortDescending
                                ? 'High to low'
                                : 'Low to high')
                            : 'High ↔ low',
                      ),
                      selected: _sortAxis == _SortAxis.amount,
                      trailing: Switch(
                        value:
                            _sortAxis == _SortAxis.amount && _sortDescending,
                        onChanged: (value) {
                          _setSortAxis(_SortAxis.amount);
                          _setSortDescending(value);
                        },
                      ),
                      onTap: () => _setSortAxis(_SortAxis.amount),
                    ),
                    if (widget.paymentSources.isNotEmpty) ...[
                      const Divider(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.page,
                        ),
                        child: Text(
                          'Payment method',
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.page,
                        ),
                        child: Text(
                          'Match any selected account',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      _buildPaymentMethodSection(theme),
                    ],
                    if (widget.categories.isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildCategorySection(theme),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.tight,
                AppSpacing.page,
                AppSpacing.page,
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _closeWithoutApply,
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
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
    );
  }
}
