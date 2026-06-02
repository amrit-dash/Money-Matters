import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_matters/models/transaction.dart';

import '../../core/widgets/app_ui.dart';
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
    await showOriginalIngestSheet(
      context,
      localDatabase: AppScope.of(context).localDatabase,
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
    final isCredit = tx.type == TransactionType.credit;
    final txId = tx.id;

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
          Card(
            color: scheme.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.displayMerchant ?? 'Unknown merchant',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${isCredit ? '+' : '-'}${_currency.format(tx.amount)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isCredit ? scheme.primary : scheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Spacer(),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.end,
                        children: [
                          if (tx.needsClassification)
                            AppStatusChip(
                              label: 'Needs category',
                              tone: AppStatTone.warning,
                            ),
                          if (tx.ambiguous)
                            AppStatusChip(
                              label: 'Ambiguous',
                              tone: AppStatTone.warning,
                            ),
                          if (tx.unmatched)
                            AppStatusChip(
                              label: 'Unmatched',
                              tone: AppStatTone.warning,
                            ),
                          if (tx.excluded)
                            AppStatusChip(
                              label: 'Excluded',
                              tone: AppStatTone.neutral,
                            ),
                          if (!tx.needsClassification &&
                              !tx.ambiguous &&
                              !tx.unmatched &&
                              !tx.excluded)
                            AppStatusChip(
                              label: 'Classified',
                              tone: AppStatTone.success,
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          _DetailRow(label: 'Category', value: _categoryName(tx)),
          _DetailRow(
            label: 'Payment source',
            value: _paymentSourceLabel(tx),
          ),
          _DetailRow(label: 'Type', value: tx.type.name.toUpperCase()),
          _DetailRow(label: 'When', value: _dateFormat.format(tx.timestamp)),
          if (tx.merchant != null)
            _DetailRow(label: 'Raw merchant', value: tx.merchant!),
          if (tx.classifiedBy != null)
            _DetailRow(
              label: 'Classified by',
              value: tx.classifiedBy!.name.toUpperCase(),
            ),
          if (tx.userNotes != null && tx.userNotes!.isNotEmpty)
            _DetailRow(label: 'Notes', value: tx.userNotes!),
          if (tx.shoppingItems.isNotEmpty)
            _DetailRow(
              label: 'Shopping list',
              value: tx.shoppingItems.join(', '),
            ),
          if (tx.travelProvider != null && tx.travelProvider!.isNotEmpty)
            _DetailRow(label: 'Travel provider', value: tx.travelProvider!),
          if (tx.categoryId == CategoryService.transferCategoryId &&
              tx.transferTo != null &&
              tx.transferTo!.isNotEmpty)
            _DetailRow(label: 'To', value: tx.transferTo!),
          _DetailRow(label: 'Currency', value: tx.currency),
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
                    child: OutlinedButton(
                      onPressed: () => _exclude(txId),
                      child: const Text('Exclude'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.item),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _delete(txId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error),
                    ),
                    child: const Text('Delete'),
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
