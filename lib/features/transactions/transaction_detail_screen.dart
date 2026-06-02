import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_matters/models/transaction.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/original_ingest_sheet.dart';
import '../../core/widgets/payment_source_picker_sheet.dart';
import '../../services/app_services.dart';
import '../../services/category_service.dart';
import '../../services/payment_source_service.dart';
import '../accounts/payment_source_widgets.dart';
import '../review/classify_screen.dart';
import '../review/review_repository.dart';

/// Full parsed view of a single transaction with a reclassify action.
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
  late Transaction _tx;
  String? _resolvedPaymentSourceName;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('EEE, d MMM yyyy · h:mm:ss a');

  @override
  void initState() {
    super.initState();
    _tx = widget.transaction;
    _resolvePaymentSourceName();
  }

  Future<void> _resolvePaymentSourceName() async {
    if (widget.paymentSourceName != null) {
      _resolvedPaymentSourceName = widget.paymentSourceName;
      return;
    }
    final sourceId = _tx.paymentSourceId;
    if (sourceId == null) return;
    try {
      final sources = await widget.paymentSourceService.loadAll();
      final matches = sources.where((s) => s.id == sourceId);
      if (!mounted || matches.isEmpty) return;
      final match = matches.first;
      setState(() => _resolvedPaymentSourceName = match.name);
    } catch (_) {}
  }

  Future<void> _changePaymentSource() async {
    final id = _tx.id;
    if (id == null) return;

    final sources = visiblePaymentSources(
      await widget.paymentSourceService.loadAll(),
    );
    if (!mounted) return;

    final picked = await showPaymentSourcePickerSheet(
      context,
      sources: sources,
      selectedId: _tx.paymentSourceId,
      title: 'Change payment source',
    );
    if (picked == null || picked.id == _tx.paymentSourceId || !mounted) return;

    await widget.reviewRepository.updatePaymentSource(
      transactionId: id,
      paymentSourceId: picked.id,
    );
    if (!mounted) return;

    setState(() {
      _tx = _tx.copyWith(
        paymentSourceId: picked.id,
        unmatched: false,
      );
      _resolvedPaymentSourceName = picked.name;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Linked to ${picked.name}')),
    );
  }

  Future<void> _viewOriginalMessage() async {
    await showOriginalIngestSheet(
      context,
      localDatabase: AppScope.of(context).localDatabase,
      rawIngestId: _tx.rawIngestId,
    );
  }

  Future<void> _reclassify() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => ClassifyScreen(
          repository: widget.reviewRepository,
          paymentSourceService: AppScope.of(ctx).paymentSourceService,
          transaction: _tx,
        ),
      ),
    );
    if (changed == true && _tx.id != null) {
      final updated = await widget.reviewRepository.transactionById(_tx.id!);
      if (updated != null && mounted) {
        setState(() {
          _tx = updated;
          if (widget.paymentSourceName == null) {
            _resolvedPaymentSourceName = null;
          }
        });
        await _resolvePaymentSourceName();
      }
    }
  }

  Future<void> _exclude() async {
    final id = _tx.id;
    if (id == null) return;

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

  Future<void> _delete() async {
    final id = _tx.id;
    if (id == null) return;

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

  String _paymentSourceLabel() {
    if (_tx.excluded) return 'Excluded from totals';
    final name = _resolvedPaymentSourceName ?? widget.paymentSourceName;
    if (name != null) return name;
    if (_tx.unmatched) return 'No linked account';
    if (_tx.paymentSourceId != null) return 'Unknown account';
    return '—';
  }

  String _categoryName() {
    final cat = widget.categoryService.findById(_tx.categoryId);
    return cat?.name ?? (_tx.categoryId ?? 'Uncategorized');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCredit = _tx.type == TransactionType.credit;

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
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
                    _tx.displayMerchant ?? 'Unknown merchant',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${isCredit ? '+' : '-'}${_currency.format(_tx.amount)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isCredit ? scheme.primary : scheme.onSurface,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          _DetailRow(label: 'Type', value: _tx.type.name.toUpperCase()),
          _DetailRow(label: 'Category', value: _categoryName()),
          _DetailRow(
            label: 'Payment source',
            value: _paymentSourceLabel(),
          ),
          _DetailRow(label: 'When', value: _dateFormat.format(_tx.timestamp)),
          if (_tx.merchant != null)
            _DetailRow(label: 'Raw merchant', value: _tx.merchant!),
          if (_tx.classifiedBy != null)
            _DetailRow(
              label: 'Classified by',
              value: _tx.classifiedBy!.name.toUpperCase(),
            ),
          if (_tx.userNotes != null && _tx.userNotes!.isNotEmpty)
            _DetailRow(label: 'Notes', value: _tx.userNotes!),
          if (_tx.shoppingItems.isNotEmpty)
            _DetailRow(
              label: 'Shopping list',
              value: _tx.shoppingItems.join(', '),
            ),
          _DetailRow(label: 'Currency', value: _tx.currency),
          _DetailRow(label: 'Ingest id', value: _tx.rawIngestId, mono: true),
          const SizedBox(height: AppSpacing.item),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_tx.needsClassification)
                AppStatusChip(label: 'Needs category', tone: AppStatTone.warning),
              if (_tx.ambiguous)
                AppStatusChip(label: 'Ambiguous', tone: AppStatTone.warning),
              if (_tx.unmatched)
                AppStatusChip(label: 'Unmatched', tone: AppStatTone.warning),
              if (_tx.excluded)
                AppStatusChip(label: 'Excluded', tone: AppStatTone.neutral),
              if (!_tx.needsClassification &&
                  !_tx.ambiguous &&
                  !_tx.unmatched &&
                  !_tx.excluded)
                AppStatusChip(label: 'Classified', tone: AppStatTone.success),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          OutlinedButton.icon(
            onPressed: _viewOriginalMessage,
            icon: const Icon(Icons.sms_outlined),
            label: const Text('View original message'),
          ),
          const SizedBox(height: AppSpacing.tight),
          OutlinedButton.icon(
            onPressed: _changePaymentSource,
            icon: const Icon(Icons.account_balance_outlined),
            label: const Text('Change payment source'),
          ),
          const SizedBox(height: AppSpacing.tight),
          FilledButton.icon(
            onPressed: _reclassify,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Reclassify'),
          ),
          if (!_tx.excluded) ...[
            const SizedBox(height: AppSpacing.tight),
            OutlinedButton.icon(
              onPressed: _exclude,
              icon: const Icon(Icons.block_outlined),
              label: const Text('Not a real transaction'),
            ),
          ],
          const SizedBox(height: AppSpacing.tight),
          TextButton.icon(
            onPressed: _delete,
            icon: Icon(Icons.delete_outline, color: scheme.error),
            label: Text(
              'Delete',
              style: TextStyle(color: scheme.error),
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
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

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
              style: mono
                  ? Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontFamily: 'monospace')
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
