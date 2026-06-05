import 'package:flutter/material.dart';
import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';

import '../../features/accounts/payment_source_widgets.dart';
import 'app_ui.dart';

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

/// Scrollable filter bottom sheet.
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

  String _paymentSourceLabel(PaymentSource source) {
    return source.last4 != null
        ? '${source.name} ···· ${source.last4}'
        : source.name;
  }

  String _selectionSummary({
    required Set<String> selectedIds,
    required Map<String, String> labelsById,
    required String emptyLabel,
    required String pluralNoun,
  }) {
    if (selectedIds.isEmpty) return emptyLabel;
    if (selectedIds.length == 1) {
      final id = selectedIds.first;
      return labelsById[id] ?? '1 $pluralNoun';
    }
    return '${selectedIds.length} $pluralNoun selected';
  }

  List<_FilterSelectGroup> _paymentSourceGroups() {
    final banks = widget.paymentSources
        .where((s) => s.type == PaymentSourceType.bank)
        .toList();
    final cards = widget.paymentSources
        .where((s) => s.type == PaymentSourceType.card)
        .toList();

    return [
      if (banks.isNotEmpty)
        _FilterSelectGroup(
          title: 'Bank accounts',
          icon: Icons.account_balance_outlined,
          items: [
            for (final source in banks)
              _FilterSelectItem(
                id: source.id,
                label: _paymentSourceLabel(source),
                subtitle: 'Bank account',
                leading: Icons.account_balance_outlined,
              ),
          ],
        ),
      if (cards.isNotEmpty)
        _FilterSelectGroup(
          title: 'Cards',
          icon: Icons.credit_card_outlined,
          items: [
            for (final source in cards)
              _FilterSelectItem(
                id: source.id,
                label: _paymentSourceLabel(source),
                subtitle: 'Card',
                leading: Icons.credit_card_outlined,
              ),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final paymentLabels = {
      for (final source in widget.paymentSources)
        source.id: _paymentSourceLabel(source),
    };
    final categoryLabels = {
      for (final category in widget.categories) category.id: category.name,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.tight,
                AppSpacing.page,
                AppSpacing.item,
              ),
              child: Text(
                'Filter transactions',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppSectionHeader(
                      title: 'Sort by',
                      icon: Icons.sort_outlined,
                    ),
                    Wrap(
                      spacing: AppSpacing.tight,
                      runSpacing: AppSpacing.tight,
                      children: [
                        for (final option in TransactionListSort.values)
                          FilterChip(
                            label: Text(_sortLabel(option)),
                            selected: _sort == option,
                            onSelected: (_) =>
                                setState(() => _sort = option),
                          ),
                      ],
                    ),
                    if (widget.paymentSources.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.section),
                      const AppSectionHeader(
                        title: 'Payment method',
                        subtitle: 'Match any selected account',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      _FilterMultiSelectField(
                        label: 'Accounts',
                        valueText: _selectionSummary(
                          selectedIds: _paymentSourceIds,
                          labelsById: paymentLabels,
                          emptyLabel: 'All accounts',
                          pluralNoun: 'accounts',
                        ),
                        selectedCount: _paymentSourceIds.length,
                        onTap: () async {
                          final picked = await _showMultiSelectPicker(
                            context,
                            title: 'Payment method',
                            groups: _paymentSourceGroups(),
                            selectedIds: _paymentSourceIds,
                          );
                          if (picked != null) {
                            setState(() => _paymentSourceIds = picked);
                          }
                        },
                      ),
                    ],
                    if (widget.categories.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.section),
                      const AppSectionHeader(
                        title: 'Category',
                        subtitle: 'Match any selected category',
                        icon: Icons.category_outlined,
                      ),
                      _FilterMultiSelectField(
                        label: 'Categories',
                        valueText: _selectionSummary(
                          selectedIds: _categoryIds,
                          labelsById: categoryLabels,
                          emptyLabel: 'All categories',
                          pluralNoun: 'categories',
                        ),
                        selectedCount: _categoryIds.length,
                        onTap: () async {
                          final picked = await _showMultiSelectPicker(
                            context,
                            title: 'Categories',
                            groups: [
                              _FilterSelectGroup(
                                items: [
                                  for (final category in widget.categories)
                                    _FilterSelectItem(
                                      id: category.id,
                                      label: category.name,
                                    ),
                                ],
                              ),
                            ],
                            selectedIds: _categoryIds,
                          );
                          if (picked != null) {
                            setState(() => _categoryIds = picked);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.section),
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
                  FilledButton(
                    onPressed: _apply,
                    child: const Text('Apply filters'),
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

String _sortLabel(TransactionListSort sort) {
  return switch (sort) {
    TransactionListSort.latestFirst => 'Latest first',
    TransactionListSort.oldestFirst => 'Oldest first',
    TransactionListSort.amountHighToLow => 'Amount: high to low',
    TransactionListSort.amountLowToHigh => 'Amount: low to high',
  };
}

class _FilterSelectItem {
  const _FilterSelectItem({
    required this.id,
    required this.label,
    this.subtitle,
    this.leading,
  });

  final String id;
  final String label;
  final String? subtitle;
  final IconData? leading;
}

class _FilterSelectGroup {
  const _FilterSelectGroup({
    required this.items,
    this.title,
    this.icon,
  });

  final String? title;
  final IconData? icon;
  final List<_FilterSelectItem> items;
}

class _FilterMultiSelectField extends StatelessWidget {
  const _FilterMultiSelectField({
    required this.label,
    required this.valueText,
    required this.selectedCount,
    required this.onTap,
  });

  final String label;
  final String valueText;
  final int selectedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                valueText,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: selectedCount == 0
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selectedCount > 0) ...[
              const SizedBox(width: AppSpacing.tight),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Text(
                  '$selectedCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<Set<String>?> _showMultiSelectPicker(
  BuildContext context, {
  required String title,
  required List<_FilterSelectGroup> groups,
  required Set<String> selectedIds,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      var draft = Set<String>.from(selectedIds);
      final allIds = [
        for (final group in groups)
          for (final item in group.items) item.id,
      ];

      return StatefulBuilder(
        builder: (context, setSheetState) {
          void toggle(String id, bool? checked) {
            setSheetState(() {
              if (checked == true) {
                draft.add(id);
              } else {
                draft.remove(id);
              }
            });
          }

          void selectAll() {
            setSheetState(() => draft = Set<String>.from(allIds));
          }

          void clearAll() {
            setSheetState(() => draft = {});
          }

          final theme = Theme.of(ctx);
          final maxHeight = MediaQuery.sizeOf(ctx).height * 0.65;

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.tight,
                      AppSpacing.page,
                      AppSpacing.item,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: draft.length == allIds.length
                              ? clearAll
                              : selectAll,
                          child: Text(
                            draft.length == allIds.length
                                ? 'Clear all'
                                : 'Select all',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final group in groups) ...[
                          if (group.title != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.page,
                                AppSpacing.tight,
                                AppSpacing.page,
                                0,
                              ),
                              child: Row(
                                children: [
                                  if (group.icon != null) ...[
                                    Icon(
                                      group.icon,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    group.title!,
                                    style: theme.textTheme.labelLarge,
                                  ),
                                ],
                              ),
                            ),
                          for (final item in group.items)
                            CheckboxListTile(
                              value: draft.contains(item.id),
                              onChanged: (checked) => toggle(item.id, checked),
                              secondary: item.leading == null
                                  ? null
                                  : Icon(item.leading),
                              title: Text(item.label),
                              subtitle: item.subtitle == null
                                  ? null
                                  : Text(item.subtitle!),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                        ],
                      ],
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
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, draft),
                      child: Text(
                        draft.isEmpty
                            ? 'Done'
                            : 'Done (${draft.length} selected)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
