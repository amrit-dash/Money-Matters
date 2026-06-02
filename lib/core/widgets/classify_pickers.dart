import 'package:flutter/material.dart';

import '../../features/accounts/payment_source_widgets.dart';
import '../../models/category.dart';
import '../../models/category_taxonomy.dart';
import '../../models/payment_source.dart';
import '../../services/category_service.dart';
import '../theme/app_theme.dart';

const _bankCollapseLimit = 2;
const _cardCollapseLimit = 0;

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
  bool _banksExpanded = false;
  bool _cardsExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoExpandGroups());
  }

  @override
  void didUpdateWidget(PaymentSourceClassifyPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      _maybeAutoExpandGroups();
    }
  }

  void _maybeAutoExpandGroups() {
    final selectedId = widget.selectedId;
    if (selectedId == null) return;

    final visible = visiblePaymentSources(widget.sources);
    PaymentSource? selected;
    for (final source in visible) {
      if (source.id == selectedId) {
        selected = source;
        break;
      }
    }
    if (selected == null) return;

    if (selected.type == PaymentSourceType.bank) {
      final banks = visible
          .where((s) => s.type == PaymentSourceType.bank)
          .toList();
      final index = banks.indexWhere((s) => s.id == selectedId);
      if (index >= _bankCollapseLimit && !_banksExpanded) {
        setState(() => _banksExpanded = true);
      }
    } else if (selected.type == PaymentSourceType.card && !_cardsExpanded) {
      setState(() => _cardsExpanded = true);
    }
  }

  List<PaymentSource> _sectionSources({
    required List<PaymentSource> allInGroup,
    required bool expanded,
    required int collapseLimit,
    required String? pinnedId,
  }) {
    final pool = pinnedId == null
        ? allInGroup
        : allInGroup.where((s) => s.id != pinnedId).toList();
    if (expanded || pool.length <= collapseLimit) return pool;
    return pool.take(collapseLimit).toList();
  }

  Widget? _loadMoreButton({
    required int hiddenCount,
    required VoidCallback onPressed,
  }) {
    if (hiddenCount <= 0) return null;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        onPressed: onPressed,
        child: Text(
          hiddenCount == 1
              ? 'Load more (1 more)'
              : 'Load more ($hiddenCount more)',
        ),
      ),
    );
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

    final allBanks =
        visible.where((s) => s.type == PaymentSourceType.bank).toList();
    final allCards =
        visible.where((s) => s.type == PaymentSourceType.card).toList();
    final pinnedId = widget.selectedId;

    PaymentSource? pinnedSource;
    if (pinnedId != null) {
      for (final source in visible) {
        if (source.id == pinnedId) {
          pinnedSource = source;
          break;
        }
      }
    }

    final banksPool = pinnedSource?.type == PaymentSourceType.bank
        ? allBanks.where((s) => s.id != pinnedId).toList()
        : allBanks;
    final cardsPool = pinnedSource?.type == PaymentSourceType.card
        ? allCards.where((s) => s.id != pinnedId).toList()
        : allCards;

    final banksShown = _sectionSources(
      allInGroup: allBanks,
      expanded: _banksExpanded,
      collapseLimit: _bankCollapseLimit,
      pinnedId: pinnedSource?.type == PaymentSourceType.bank ? pinnedId : null,
    );
    final cardsShown = _sectionSources(
      allInGroup: allCards,
      expanded: _cardsExpanded,
      collapseLimit: _cardCollapseLimit,
      pinnedId: pinnedSource?.type == PaymentSourceType.card ? pinnedId : null,
    );

    final banksHidden = banksPool.length - banksShown.length;
    final cardsHidden = cardsPool.length - cardsShown.length;
    final showBankSection = banksShown.isNotEmpty || banksHidden > 0;
    final showCardSection = cardsShown.isNotEmpty || cardsHidden > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pinnedSource != null) ...[
          _SourceTile(
            source: pinnedSource,
            selected: true,
            onTap: () => widget.onSelected(pinnedSource!.id),
          ),
          if (showBankSection || showCardSection)
            const SizedBox(height: AppSpacing.item),
        ],
        if (showBankSection) ...[
          _SectionLabel(
            icon: Icons.account_balance_outlined,
            title: 'Bank accounts',
          ),
          ...banksShown.map(
            (s) => _SourceTile(
              source: s,
              selected: s.id == widget.selectedId,
              onTap: () => widget.onSelected(s.id),
            ),
          ),
          if (!_banksExpanded && banksHidden > 0) ...[
            const SizedBox(height: AppSpacing.tight),
            _loadMoreButton(
              hiddenCount: banksHidden,
              onPressed: () => setState(() => _banksExpanded = true),
            )!,
          ],
        ],
        if (showCardSection) ...[
          if (showBankSection) const SizedBox(height: AppSpacing.item),
          _SectionLabel(
            icon: Icons.credit_card_outlined,
            title: 'Cards',
          ),
          ...cardsShown.map(
            (s) => _SourceTile(
              source: s,
              selected: s.id == widget.selectedId,
              onTap: () => widget.onSelected(s.id),
            ),
          ),
          if (!_cardsExpanded && cardsHidden > 0) ...[
            const SizedBox(height: AppSpacing.tight),
            _loadMoreButton(
              hiddenCount: cardsHidden,
              onPressed: () => setState(() => _cardsExpanded = true),
            )!,
          ],
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
