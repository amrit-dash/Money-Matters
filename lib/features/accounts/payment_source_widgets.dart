import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:money_matters/models/payment_source.dart';

import '../../core/theme/app_theme.dart';

/// Banks and cards only — wallet sources are excluded from the UI.
List<PaymentSource> visiblePaymentSources(List<PaymentSource> sources) =>
    sources.where((s) => s.type != PaymentSourceType.wallet).toList();

bool hasBankOrCard(List<PaymentSource> sources) => sources.any(
      (s) =>
          s.type == PaymentSourceType.bank ||
          s.type == PaymentSourceType.card,
    );

/// Reusable list + editor for banks and cards.
class PaymentSourcesBody extends StatelessWidget {
  const PaymentSourcesBody({
    super.key,
    required this.sources,
    required this.onSourcesChanged,
    this.introText,
    this.showWalletNote = true,
  });

  final List<PaymentSource> sources;
  final ValueChanged<List<PaymentSource>> onSourcesChanged;
  final String? introText;
  final bool showWalletNote;

  @override
  Widget build(BuildContext context) {
    final visible = visiblePaymentSources(sources);
    final banks = visible.where((s) => s.type == PaymentSourceType.bank);
    final cards = visible.where((s) => s.type == PaymentSourceType.card);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        if (introText != null)
          Text(
            introText!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        if (showWalletNote) ...[
          if (introText != null) const SizedBox(height: AppSpacing.tight),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Banks and cards only — not wallet apps. '
                      'Wallet SMS are matched via your bank/card sender hints.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        PaymentSourceSectionHeader(
          title: 'Banks',
          count: banks.length,
          onAdd: () => _openEditor(context, PaymentSourceType.bank),
        ),
        if (banks.isEmpty)
          _EmptySectionHint(type: 'bank')
        else
          ...banks.map(
            (s) => PaymentSourceTile(
              source: s,
              onEdit: () => _openEditor(
                context,
                PaymentSourceType.bank,
                existing: s,
              ),
              onDelete: () => _delete(context, s),
            ),
          ),
        const SizedBox(height: AppSpacing.section),
        PaymentSourceSectionHeader(
          title: 'Cards',
          count: cards.length,
          onAdd: () => _openEditor(context, PaymentSourceType.card),
        ),
        if (cards.isEmpty)
          _EmptySectionHint(type: 'card')
        else
          ...cards.map(
            (s) => PaymentSourceTile(
              source: s,
              onEdit: () => _openEditor(
                context,
                PaymentSourceType.card,
                existing: s,
              ),
              onDelete: () => _delete(context, s),
            ),
          ),
      ],
    );
  }

  void _delete(BuildContext context, PaymentSource source) {
    final remaining = List<PaymentSource>.from(sources)..remove(source);
    if (!hasBankOrCard(remaining)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep at least one bank or card for SMS matching.'),
        ),
      );
      return;
    }
    onSourcesChanged(remaining);
  }

  Future<void> _openEditor(
    BuildContext context,
    PaymentSourceType type, {
    PaymentSource? existing,
  }) async {
    final result = await showModalBottomSheet<PaymentSource>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PaymentSourceEditor(
        type: type,
        existing: existing,
      ),
    );
    if (result == null) return;

    final updated = List<PaymentSource>.from(sources);
    if (existing != null) {
      final index = updated.indexWhere((s) => s.id == existing.id);
      if (index >= 0) updated[index] = result;
    } else {
      updated.add(result);
    }
    onSourcesChanged(updated);
  }
}

class _EmptySectionHint extends StatelessWidget {
  const _EmptySectionHint({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.item),
      child: Text(
        'No ${type}s yet — tap + to add one.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class PaymentSourceSectionHeader extends StatelessWidget {
  const PaymentSourceSectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.onAdd,
  });

  final String title;
  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.item),
      child: Row(
        children: [
          Text('$title ($count)', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class PaymentSourceTile extends StatelessWidget {
  const PaymentSourceTile({
    super.key,
    required this.source,
    required this.onEdit,
    required this.onDelete,
  });

  final PaymentSource source;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final typeLabel = source.type == PaymentSourceType.bank ? 'Bank' : 'Card';
    final hints = source.senderHints.isEmpty
        ? 'No sender hints'
        : source.senderHints.join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.tight),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(source.name),
          subtitle: Text('•••• ${source.last4 ?? '????'} · $typeLabel · $hints'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentSourceEditor extends StatefulWidget {
  const PaymentSourceEditor({super.key, required this.type, this.existing});

  final PaymentSourceType type;
  final PaymentSource? existing;

  @override
  State<PaymentSourceEditor> createState() => _PaymentSourceEditorState();
}

class _PaymentSourceEditorState extends State<PaymentSourceEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _last4Controller;
  late final TextEditingController _hintsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _last4Controller =
        TextEditingController(text: widget.existing?.last4 ?? '');
    _hintsController = TextEditingController(
      text: widget.existing?.senderHints.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _last4Controller.dispose();
    _hintsController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final last4 = _last4Controller.text.trim();
    if (name.isEmpty || last4.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and 4-digit last4 required')),
      );
      return;
    }

    final hints = _hintsController.text
        .split(',')
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toList();

    final source = PaymentSource(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: name,
      type: widget.type,
      last4: last4,
      senderHints: hints,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    Navigator.pop(context, source);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.type == PaymentSourceType.bank ? 'Bank' : 'Card';
    final action = widget.existing != null ? 'Edit' : 'Add';
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.page,
        right: AppSpacing.page,
        top: AppSpacing.page,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.page,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$action $label', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.section),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: '$label name',
            ),
          ),
          const SizedBox(height: AppSpacing.item),
          TextField(
            controller: _last4Controller,
            decoration: const InputDecoration(
              labelText: 'Last 4 digits',
            ),
            keyboardType: TextInputType.number,
            maxLength: 4,
          ),
          const SizedBox(height: AppSpacing.item),
          TextField(
            controller: _hintsController,
            decoration: const InputDecoration(
              labelText: 'Sender hints (comma-separated)',
              hintText: 'VK-HDFCBK, FEDBNK-S',
              helperText:
                  'SMS sender IDs from your bank (e.g. FEDBNK-S for Federal Bank)',
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
