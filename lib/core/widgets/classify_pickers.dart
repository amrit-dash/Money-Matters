import 'package:flutter/material.dart';

import '../../features/accounts/payment_source_widgets.dart';
import '../../models/category.dart';
import '../../models/payment_source.dart';
import '../../services/category_service.dart';
import '../theme/app_theme.dart';

const _paymentSourceCollapseThreshold = 2;

/// Banks and cards in separate sections for the classify flow.
class PaymentSourceClassifyPicker extends StatefulWidget {
  const PaymentSourceClassifyPicker({
    super.key,
    required this.sources,
    required this.selectedId,
    required this.onSelected,
  });

  final List<PaymentSource> sources;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  State<PaymentSourceClassifyPicker> createState() =>
      _PaymentSourceClassifyPickerState();
}

class _PaymentSourceClassifyPickerState extends State<PaymentSourceClassifyPicker> {
  bool _showAll = false;

  @override
  void didUpdateWidget(PaymentSourceClassifyPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId &&
        widget.selectedId != null &&
        !_showAll) {
      final visible = visiblePaymentSources(widget.sources);
      final hiddenSelected = visible.length >
              _paymentSourceCollapseThreshold &&
          visible
              .skip(_paymentSourceCollapseThreshold)
              .any((s) => s.id == widget.selectedId);
      if (hiddenSelected) {
        _showAll = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = visiblePaymentSources(widget.sources);
    final scheme = Theme.of(context).colorScheme;

    if (visible.isEmpty) {
      return Text(
        'Add a bank or card in Accounts first.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      );
    }

    final canCollapse = visible.length > _paymentSourceCollapseThreshold;
    final shown = canCollapse && !_showAll
        ? visible.take(_paymentSourceCollapseThreshold).toList()
        : visible;
    final banks =
        shown.where((s) => s.type == PaymentSourceType.bank).toList();
    final cards =
        shown.where((s) => s.type == PaymentSourceType.card).toList();
    final hiddenCount = visible.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banks.isNotEmpty) ...[
          _SectionLabel(
            icon: Icons.account_balance_outlined,
            title: 'Bank accounts',
          ),
          ...banks.map(
            (s) => _SourceTile(
              source: s,
              selected: s.id == widget.selectedId,
              onTap: () => widget.onSelected(s.id),
            ),
          ),
        ],
        if (cards.isNotEmpty) ...[
          if (banks.isNotEmpty) const SizedBox(height: AppSpacing.item),
          _SectionLabel(
            icon: Icons.credit_card_outlined,
            title: 'Cards',
          ),
          ...cards.map(
            (s) => _SourceTile(
              source: s,
              selected: s.id == widget.selectedId,
              onTap: () => widget.onSelected(s.id),
            ),
          ),
        ],
        if (canCollapse && !_showAll) ...[
          const SizedBox(height: AppSpacing.tight),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showAll = true),
              child: Text(
                hiddenCount == 1
                    ? 'Load more (1 more)'
                    : 'Load more ($hiddenCount more)',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.tight),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final PaymentSource source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = source.last4 != null
        ? '${source.name} ···· ${source.last4}'
        : source.name;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.tight),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  source.type == PaymentSourceType.card
                      ? Icons.credit_card_outlined
                      : Icons.account_balance_outlined,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: scheme.primary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Preset + custom ride/travel provider chips for classify / reclassify.
class TravelProviderPicker extends StatelessWidget {
  const TravelProviderPicker({
    super.key,
    required this.selectedProvider,
    required this.customMode,
    required this.customController,
    required this.onPresetSelected,
    required this.onCustomMode,
  });

  final String? selectedProvider;
  final bool customMode;
  final TextEditingController customController;
  final ValueChanged<String?> onPresetSelected;
  final VoidCallback onCustomMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...CategoryService.defaultTravelProviders.map((provider) {
              final selected = !customMode && selectedProvider == provider;
              return FilterChip(
                label: Text(provider),
                selected: selected,
                onSelected: (_) => onPresetSelected(provider),
                showCheckmark: true,
              );
            }),
            FilterChip(
              label: const Text('Custom'),
              selected: customMode,
              onSelected: (_) => onCustomMode(),
              showCheckmark: true,
            ),
          ],
        ),
        if (customMode) ...[
          const SizedBox(height: AppSpacing.tight),
          TextField(
            controller: customController,
            decoration: const InputDecoration(
              hintText: 'e.g. Namma Yatri, BluSmart',
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ],
    );
  }
}

/// Subcategory chips under a parent category (bills, food, transport, travel).
class SubcategoryClassifyPicker extends StatelessWidget {
  const SubcategoryClassifyPicker({
    super.key,
    required this.categoryId,
    required this.selectedSubcategoryId,
    required this.onSelected,
  });

  final String categoryId;
  final String? selectedSubcategoryId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final subs = CategoryService.subcategoriesFor(categoryId);
    if (subs.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: subs.map((sub) {
        final selected = sub.id == selectedSubcategoryId;
        return FilterChip(
          label: Text(sub.label),
          selected: selected,
          onSelected: (_) => onSelected(selected ? null : sub.id),
          showCheckmark: true,
        );
      }).toList(),
    );
  }
}

/// Wrap of category chips for classify / reclassify.
class CategoryClassifyPicker extends StatelessWidget {
  const CategoryClassifyPicker({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final selected = cat.id == selectedId;
        return FilterChip(
          label: Text(cat.name),
          selected: selected,
          onSelected: (_) => onSelected(cat.id),
          showCheckmark: true,
        );
      }).toList(),
    );
  }
}
