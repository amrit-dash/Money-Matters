import 'package:flutter/material.dart';

import '../../features/accounts/payment_source_widgets.dart';
import '../../models/category.dart';
import '../../models/payment_source.dart';
import '../theme/app_theme.dart';

/// Banks and cards in separate sections for the classify flow.
class PaymentSourceClassifyPicker extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final visible = visiblePaymentSources(sources);
    final banks = visible.where((s) => s.type == PaymentSourceType.bank).toList();
    final cards = visible.where((s) => s.type == PaymentSourceType.card).toList();
    final scheme = Theme.of(context).colorScheme;

    if (visible.isEmpty) {
      return Text(
        'Add a bank or card in Accounts first.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      );
    }

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
              selected: s.id == selectedId,
              onTap: () => onSelected(s.id),
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
              selected: s.id == selectedId,
              onTap: () => onSelected(s.id),
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
