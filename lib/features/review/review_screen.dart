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
  const ReviewScreen({
    super.key,
    required this.repository,
    this.embeddedInShell = false,
    this.onListChanged,
  });

  final ReviewRepository repository;
  final bool embeddedInShell;
  final VoidCallback? onListChanged;

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
    widget.onListChanged?.call();
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
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embeddedInShell,
        title: Text(widget.embeddedInShell ? 'Inbox' : 'Needs your input'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? AppEmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'All clear',
                  message:
                      'Nothing needs you right now. When we are unsure about a '
                      'category or account, it will show up here for a quick tap.',
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
                              'Tap a row to pick a category, notes, or items',
                          icon: Icons.label_outline,
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

    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    scheme.tertiaryContainer.withValues(alpha: 0.75),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 12),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
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
    );
  }
}
