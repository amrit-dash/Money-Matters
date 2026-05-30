import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_matters/models/transaction.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import 'relabel_sheet.dart';
import 'review_repository.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.repository});

  final ReviewRepository repository;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<Transaction> _items = [];
  bool _loading = true;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('d MMM, h:mm a');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await widget.repository.flaggedTransactions();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _openRelabel(Transaction tx) async {
    final categories = await widget.repository.availableCategories();
    if (!mounted) return;

    final result = await showModalBottomSheet<RelabelResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RelabelSheet(transaction: tx, categories: categories),
    );
    if (result == null || tx.id == null) return;

    try {
      await widget.repository.relabel(
        transactionId: tx.id!,
        categoryId: result.categoryId,
        merchantRuleHint: result.saveMerchantRule ? tx.merchant : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category updated')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save category: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? AppEmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'All clear',
                  message:
                      'No flagged transactions need review right now.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    itemCount: _items.length + 1,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.tight),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return AppSectionHeader(
                          title: 'Flagged (${_items.length})',
                          subtitle:
                              'Ambiguous categories or unmatched payment sources',
                        );
                      }
                      final tx = _items[index - 1];
                      return _FlaggedTile(
                        transaction: tx,
                        amountLabel: _currency.format(tx.amount),
                        dateLabel: _dateFormat.format(tx.timestamp),
                        onRelabel: () => _openRelabel(tx),
                      );
                    },
                  ),
                ),
    );
  }
}

class _FlaggedTile extends StatelessWidget {
  const _FlaggedTile({
    required this.transaction,
    required this.amountLabel,
    required this.dateLabel,
    required this.onRelabel,
  });

  final Transaction transaction;
  final String amountLabel;
  final String dateLabel;
  final VoidCallback onRelabel;

  @override
  Widget build(BuildContext context) {
    final flags = <String>[
      if (transaction.ambiguous) 'Ambiguous',
      if (transaction.unmatched) 'Unmatched',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.merchant ?? 'Unknown merchant',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  amountLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            if (flags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.tight),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: flags
                    .map(
                      (f) => AppStatusChip(
                        label: f,
                        tone: AppStatTone.warning,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: AppSpacing.item),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onRelabel,
                child: const Text('Relabel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
