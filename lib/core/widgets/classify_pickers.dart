import 'package:flutter/material.dart';

import '../../features/accounts/payment_source_widgets.dart';
import '../../models/category.dart';
import '../../models/category_taxonomy.dart';
import '../../models/payment_source.dart';
import '../../services/category_service.dart';
import '../theme/app_theme.dart';

String _paymentSourceLabel(PaymentSource source) {
  return source.last4 != null
      ? '${source.name} ···· ${source.last4}'
      : source.name;
}

/// Banks and cards as dropdowns for the classify / reclassify flow.
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
    final scheme = Theme.of(context).colorScheme;

    if (visible.isEmpty) {
      return Text(
        'Add a bank or card in Accounts first.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      );
    }

    final banks =
        visible.where((s) => s.type == PaymentSourceType.bank).toList();
    final cards =
        visible.where((s) => s.type == PaymentSourceType.card).toList();

    PaymentSource? selectedSource;
    if (selectedId != null) {
      for (final source in visible) {
        if (source.id == selectedId) {
          selectedSource = source;
          break;
        }
      }
    }

    final bankLocked =
        selectedSource?.type == PaymentSourceType.card;
    final cardLocked =
        selectedSource?.type == PaymentSourceType.bank;

    final bankValue = selectedSource?.type == PaymentSourceType.bank
        ? selectedId
        : null;
    final cardValue = selectedSource?.type == PaymentSourceType.card
        ? selectedId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedSource != null) ...[
          _SectionLabel(
            icon: Icons.check_circle_outline,
            title: 'Selected',
          ),
          _SelectedSourceRow(
            source: selectedSource,
            onClear: () => onSelected(null),
          ),
          if (banks.isNotEmpty || cards.isNotEmpty)
            const SizedBox(height: AppSpacing.item),
        ],
        if (banks.isNotEmpty) ...[
          _SectionLabel(
            icon: Icons.account_balance_outlined,
            title: 'Bank accounts',
          ),
          _PaymentSourceDropdown(
            fieldKey: 'bank',
            sources: banks,
            value: bankValue,
            hint: 'Select bank account',
            enabled: !bankLocked,
            onChanged: onSelected,
          ),
        ],
        if (cards.isNotEmpty) ...[
          if (banks.isNotEmpty) const SizedBox(height: AppSpacing.item),
          _SectionLabel(
            icon: Icons.credit_card_outlined,
            title: 'Cards',
          ),
          _PaymentSourceDropdown(
            fieldKey: 'card',
            sources: cards,
            value: cardValue,
            hint: 'Select card',
            enabled: !cardLocked,
            onChanged: onSelected,
          ),
        ],
      ],
    );
  }
}

class _PaymentSourceDropdown extends StatelessWidget {
  const _PaymentSourceDropdown({
    required this.fieldKey,
    required this.sources,
    required this.value,
    required this.hint,
    required this.enabled,
    required this.onChanged,
  });

  final String fieldKey;
  final List<PaymentSource> sources;
  final String? value;
  final String hint;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$fieldKey-$value'),
      initialValue: value,
      decoration: InputDecoration(
        hintText: hint,
        enabled: enabled,
      ),
      isExpanded: true,
      items: sources
          .map(
            (source) => DropdownMenuItem(
              value: source.id,
              child: Text(_paymentSourceLabel(source)),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _SelectedSourceRow extends StatelessWidget {
  const _SelectedSourceRow({
    required this.source,
    required this.onClear,
  });

  final PaymentSource source;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = source.type == PaymentSourceType.card
        ? Icons.credit_card_outlined
        : Icons.account_balance_outlined;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _paymentSourceLabel(source),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            IconButton(
              tooltip: 'Clear selection',
              onPressed: onClear,
              icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
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

/// Preset service / store chips for subcategories with known merchants.
class ServiceProviderPicker extends StatelessWidget {
  const ServiceProviderPicker({
    super.key,
    required this.providers,
    required this.selectedProvider,
    required this.customMode,
    required this.customController,
    required this.onPresetSelected,
    required this.onCustomMode,
  });

  final List<String> providers;
  final String? selectedProvider;
  final bool customMode;
  final TextEditingController customController;
  final ValueChanged<String> onPresetSelected;
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
            ...providers.map((provider) {
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
              hintText: 'Enter name',
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
    this.selectedServiceProvider,
    this.serviceProviderCustom = false,
    this.customServiceProviderController,
    this.onServiceProviderSelected,
    this.onServiceProviderCustomMode,
  });

  final String categoryId;
  final String? selectedSubcategoryId;
  final ValueChanged<String?> onSelected;
  final String? selectedServiceProvider;
  final bool serviceProviderCustom;
  final TextEditingController? customServiceProviderController;
  final ValueChanged<String>? onServiceProviderSelected;
  final VoidCallback? onServiceProviderCustomMode;

  @override
  Widget build(BuildContext context) {
    final subs = CategoryService.subcategoriesFor(categoryId);
    if (subs.isEmpty) return const SizedBox.shrink();

    final showProviders = selectedSubcategoryId != null &&
        subcategoryHasServiceProviders(categoryId, selectedSubcategoryId);
    final providers = showProviders
        ? serviceProvidersFor(categoryId, selectedSubcategoryId)
        : const <String>[];
    final providerLabel = categoryId == 'shopping' ? 'Store' : 'Service';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.tight),
          child: Text(
            'Subcategory',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Wrap(
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
        ),
        if (showProviders &&
            onServiceProviderSelected != null &&
            customServiceProviderController != null &&
            onServiceProviderCustomMode != null) ...[
          const SizedBox(height: AppSpacing.item),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.tight),
            child: Text(
              providerLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          ServiceProviderPicker(
            providers: providers,
            selectedProvider: selectedServiceProvider,
            customMode: serviceProviderCustom,
            customController: customServiceProviderController!,
            onPresetSelected: onServiceProviderSelected!,
            onCustomMode: onServiceProviderCustomMode!,
          ),
        ],
      ],
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
