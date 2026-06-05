import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_matters/models/category_taxonomy.dart';
import 'package:money_matters/models/transaction.dart';

import '../../core/widgets/app_ui.dart';
import '../../core/widgets/category_icons.dart';
import '../../core/widgets/original_ingest_sheet.dart';
import '../../services/app_services.dart';
import '../../services/category_service.dart';
import '../../services/payment_source_service.dart';
import '../review/classify_screen.dart';
import '../review/review_repository.dart';

/// Full parsed view of a single transaction with reclassify actions.
class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.reviewRepository,
    required this.categoryService,
    required this.paymentSourceService,
    this.paymentSourceName,
  });

  final Transaction transaction;
  final ReviewRepository reviewRepository;
  final CategoryService categoryService;
  final PaymentSourceService paymentSourceService;
  final String? paymentSourceName;

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  String? _resolvedPaymentSourceName;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('EEE, d MMM yyyy · h:mm:ss a');
  final _headerDateFormat = DateFormat('d MMM yyyy, h:mm a');

  @override
  void initState() {
    super.initState();
    _resolvePaymentSourceName(widget.transaction);
  }

  Future<void> _resolvePaymentSourceName(Transaction tx) async {
    if (widget.paymentSourceName != null) {
      setState(() => _resolvedPaymentSourceName = widget.paymentSourceName);
      return;
    }
    final sourceId = tx.paymentSourceId;
    if (sourceId == null) return;
    try {
      final sources = await widget.paymentSourceService.loadAll();
      final matches = sources.where((s) => s.id == sourceId);
      if (!mounted || matches.isEmpty) return;
      final match = matches.first;
      setState(() => _resolvedPaymentSourceName = match.name);
    } catch (_) {}
  }

  Future<void> _openReclassify(Transaction tx) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => ClassifyScreen(
          repository: widget.reviewRepository,
          paymentSourceService: AppScope.of(ctx).paymentSourceService,
          transaction: tx,
        ),
      ),
    );
    if (changed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _viewOriginalMessage(Transaction tx) async {
    final scope = AppScope.of(context);
    await showOriginalIngestSheet(
      context,
      localDatabase: scope.localDatabase,
      ingestRepository: scope.ingestRepository,
      rawIngestId: tx.rawIngestId,
    );
  }

  Future<void> _exclude(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Not a real transaction?'),
        content: const Text(
          'This will remove the transaction from your totals and dashboard. '
          'Use this for promos, loan offers, or other false positives.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exclude'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await widget.reviewRepository.excludeTransaction(id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'This permanently removes the transaction from your records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await widget.reviewRepository.deleteTransaction(id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  String _paymentSourceLabel(Transaction tx) {
    if (tx.excluded) return 'Excluded from totals';
    final name = _resolvedPaymentSourceName ?? widget.paymentSourceName;
    if (name != null) return name;
    if (tx.unmatched) return 'No linked account';
    if (tx.paymentSourceId != null) return 'Unknown account';
    return '—';
  }

  String _categoryName(Transaction tx) {
    final cat = widget.categoryService.findById(tx.categoryId);
    return cat?.name ?? (tx.categoryId ?? 'Uncategorized');
  }

  List<Widget> _headerStatusChips(Transaction tx) {
    if (tx.needsClassification || tx.ambiguous || tx.categoryId == null) {
      return [
        AppStatusChip(
          label: 'Unclassified',
          tone: AppStatTone.warning,
        ),
      ];
    }

    return switch (tx.classifiedBy) {
      ClassifiedBy.llm => [
          _ClassificationTag(
            label: 'AI classified',
            icon: Icons.auto_awesome_outlined,
          ),
        ],
      ClassifiedBy.user => [
          _ClassificationTag(
            label: 'User classified',
            icon: Icons.person_outline,
          ),
        ],
      _ => const <Widget>[],
    };
  }

  String? _paidToLabel(Transaction tx) => tx.displayMerchant;

  @override
  Widget build(BuildContext context) {
    final txId = widget.transaction.id;
    if (txId == null) {
      return _buildScaffold(context, widget.transaction);
    }

    return StreamBuilder<Transaction?>(
      stream: widget.reviewRepository.watchTransaction(txId),
      initialData: widget.transaction,
      builder: (context, snapshot) {
        final tx = snapshot.data ?? widget.transaction;
        if (tx.paymentSourceId != widget.transaction.paymentSourceId ||
            tx.categoryId != widget.transaction.categoryId) {
          _resolvePaymentSourceName(tx);
        }
        return _buildScaffold(context, tx);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Transaction tx) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isCredit = tx.type == TransactionType.credit;
    final txId = tx.id;
    final categoryName = _categoryName(tx);
    final categoryIcon = categoryIconFor(
      categoryId: tx.categoryId,
      subcategoryId: tx.subcategoryId,
      travelProvider: tx.travelProvider,
    );
    final statusChips = _headerStatusChips(tx);
    final paidTo = _paidToLabel(tx);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Reclassify',
              onPressed: () => _openReclassify(tx),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AppCard(
            color: scheme.secondaryContainer.withValues(alpha: 0.35),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _headerDateFormat.format(tx.timestamp),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.displayMerchant ?? 'Unknown merchant',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${isCredit ? '+' : '-'}${_currency.format(tx.amount)}',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isCredit
                                  ? scheme.primary
                                  : scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      categoryIcon,
                      size: 44,
                      color: scheme.onSecondaryContainer,
                    ),
                  ],
                ),
                if (statusChips.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: statusChips.first,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          if (paidTo != null && paidTo.isNotEmpty)
            _DetailRow(label: 'Paid to', value: paidTo),
          _DetailRow(label: 'Category', value: categoryName),
          if (tx.subcategoryId != null && tx.subcategoryId!.isNotEmpty)
            _DetailRow(
              label: 'Subcategory',
              value: subcategoryLabel(tx.categoryId, tx.subcategoryId) ??
                  tx.subcategoryId!,
            ),
          if (tx.travelProvider != null && tx.travelProvider!.isNotEmpty)
            _DetailRow(label: 'Travel mode', value: tx.travelProvider!),
          if (tx.categoryId == CategoryService.transferCategoryId &&
              tx.transferTo != null &&
              tx.transferTo!.isNotEmpty)
            _DetailRow(label: 'Transfer to', value: tx.transferTo!),
          if (tx.merchant != null)
            _DetailRow(label: 'Raw merchant', value: tx.merchant!),
          if (tx.shoppingItems.isNotEmpty)
            _DetailRow(
              label: 'Shopping list',
              value: tx.shoppingItems.join(', '),
            ),
          _DetailRow(
            label: 'Payment source',
            value: _paymentSourceLabel(tx),
          ),
          _DetailRow(label: 'Type', value: tx.type.name.toUpperCase()),
          _DetailRow(label: 'When', value: _dateFormat.format(tx.timestamp)),
          _DetailRow(label: 'Currency', value: tx.currency),
          if (tx.userNotes != null && tx.userNotes!.isNotEmpty)
            _DetailRow(label: 'Notes', value: tx.userNotes!),
          const SizedBox(height: AppSpacing.section),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _viewOriginalMessage(tx),
              icon: const Icon(Icons.sms_outlined),
              label: const Text('View original message'),
            ),
          ),
          if (txId != null) ...[
            const SizedBox(height: AppSpacing.item),
            Row(
              children: [
                if (!tx.excluded) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exclude(txId),
                      icon: const Icon(Icons.block_outlined),
                      label: const Text('Exclude'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.item),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _delete(txId),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ClassificationTag extends StatelessWidget {
  const _ClassificationTag({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
