import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_matters/models/transaction.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'No flagged transactions',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final tx = _items[index];
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
      if (transaction.ambiguous) 'Ambiguous category',
      if (transaction.unmatched) 'Unmatched source',
    ];

    return Card(
      child: ListTile(
        title: Text(transaction.merchant ?? 'Unknown merchant'),
        subtitle: Text('$dateLabel · ${flags.join(' · ')}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(amountLabel, style: Theme.of(context).textTheme.titleMedium),
            TextButton(onPressed: onRelabel, child: const Text('Relabel')),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
