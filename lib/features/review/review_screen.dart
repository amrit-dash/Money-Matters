import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_matters/models/transaction.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import '../../services/app_services.dart';
import 'classify_screen.dart';
import 'review_repository.dart';

/// "Needs your input" inbox — the in-app fallback for classification that works
/// without push notifications (no paid Apple account required).
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

  Future<void> _openClassify(Transaction tx) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => ClassifyScreen(
          repository: widget.repository,
          paymentSourceService: AppScope.of(ctx).paymentSourceService,
          transaction: tx,
        ),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Needs your input')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? AppEmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'All clear',
                  message:
                      'No transactions need your input right now. New ones '
                      'show up here when a category or payment source is unknown.',
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
                          title: 'To classify (${_items.length})',
                          subtitle:
                              'Tap to pick a category, add notes or shopping items',
                        );
                      }
                      final tx = _items[index - 1];
                      return _FlaggedTile(
                        transaction: tx,
                        amountLabel: _currency.format(tx.amount),
                        dateLabel: _dateFormat.format(tx.timestamp),
                        onTap: () => _openClassify(tx),
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
    required this.onTap,
  });

  final Transaction transaction;
  final String amountLabel;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final flags = <String>[
      if (transaction.needsClassification) 'Needs category',
      if (transaction.ambiguous) 'Ambiguous',
      if (transaction.unmatched) 'Unmatched',
    ];

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                          transaction.displayMerchant ?? 'Unknown merchant',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateLabel,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
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
            ],
          ),
        ),
      ),
    );
  }
}
