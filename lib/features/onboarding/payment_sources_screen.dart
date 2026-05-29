import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:money_matters/models/payment_source.dart';

import 'onboarding_state.dart';

class PaymentSourcesScreen extends StatelessWidget {
  const PaymentSourcesScreen({
    super.key,
    required this.state,
    required this.onContinue,
  });

  final OnboardingState state;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment sources')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final banks =
              state.paymentSources.where((s) => s.type == PaymentSourceType.bank);
          final cards =
              state.paymentSources.where((s) => s.type == PaymentSourceType.card);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Add at least one bank or card that sends you debit/credit SMS. '
                      'You can add more anytime.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Banks and cards only — not wallet apps (e.g. MobiKwik). '
                      'Those SMS are matched via your bank/card sender hints.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _SectionHeader(
                      title: 'Banks (${banks.length})',
                      onAdd: () => _openEditor(context, PaymentSourceType.bank),
                    ),
                    ...banks.map(
                      (s) => _SourceTile(
                        source: s,
                        onEdit: () => _openEditor(
                          context,
                          PaymentSourceType.bank,
                          existing: s,
                        ),
                        onDelete: () => _delete(context, s),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Cards (${cards.length})',
                      onAdd: () => _openEditor(context, PaymentSourceType.card),
                    ),
                    ...cards.map(
                      (s) => _SourceTile(
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: state.paymentSourcesComplete ? onContinue : null,
                  child: const Text('Continue'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _delete(BuildContext context, PaymentSource source) {
    final index = state.paymentSources.indexOf(source);
    if (index >= 0) state.removePaymentSource(index);
  }

  Future<void> _openEditor(
    BuildContext context,
    PaymentSourceType type, {
    PaymentSource? existing,
  }) async {
    final result = await showModalBottomSheet<PaymentSource>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentSourceEditor(
        type: type,
        existing: existing,
      ),
    );
    if (result == null) return;

    if (existing != null) {
      final index = state.paymentSources.indexOf(existing);
      if (index >= 0) state.updatePaymentSource(index, result);
    } else {
      state.addPaymentSource(result);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onAdd,
  });

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          tooltip: 'Add',
        ),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
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
    return Card(
      child: ListTile(
        title: Text(source.name),
        subtitle: Text(
          '$typeLabel · **${source.last4 ?? '????'} · ${source.senderHints.join(', ')}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

class _PaymentSourceEditor extends StatefulWidget {
  const _PaymentSourceEditor({required this.type, this.existing});

  final PaymentSourceType type;
  final PaymentSource? existing;

  @override
  State<_PaymentSourceEditor> createState() => _PaymentSourceEditorState();
}

class _PaymentSourceEditorState extends State<_PaymentSourceEditor> {
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
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add $label', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: '$label name',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _last4Controller,
            decoration: const InputDecoration(
              labelText: 'Last 4 digits',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            maxLength: 4,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hintsController,
            decoration: const InputDecoration(
              labelText: 'Sender hints (comma-separated)',
              hintText: 'VK-HDFCBK, AD-HDFCBK',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
