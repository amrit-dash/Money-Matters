import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_matters/models/transaction.dart';

import '../../core/theme/app_theme.dart';
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
  late Transaction _tx;
  String? _resolvedPaymentSourceName;
  bool _aiLoading = false;

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

  Future<void> _reloadTransaction() async {
    final id = _tx.id;
    if (id == null) return;
    final updated = await widget.reviewRepository.transactionById(id);
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

  Future<void> _openReclassify() async {
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
    if (changed == true) await _reloadTransaction();
  }

  Future<void> _reclassifyWithAi() async {
    if (_aiLoading) return;
    setState(() => _aiLoading = true);
    try {
      final services = AppScope.of(context);
      final outcome =
          await services.aiClassifyService.applyToTransaction(_tx);
      if (!mounted) return;
      if (outcome.needsConfig) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI classify needs GEMINI_API_KEY on Cloud Functions. '
              'Set the secret in Firebase, then try again.',
            ),
          ),
        );
        return;
      }
      if (outcome.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI classify failed: ${outcome.error}')),
        );
        return;
      }
      final updated = outcome.transaction;
      if (updated == null || updated == _tx) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI had no changes to suggest')),
        );
        return;
      }
      await widget.reviewRepository.persistAiClassification(updated);
      if (!mounted) return;
      setState(() => _tx = updated);
      await _resolvePaymentSourceName();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updated with AI classification')),
      );
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _viewOriginalMessage() async {
    await showOriginalIngestSheet(
      context,
      localDatabase: AppScope.of(context).localDatabase,
      rawIngestId: _tx.rawIngestId,
    );
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
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Reclassify',
            onPressed: _openReclassify,
          ),
          IconButton(
            icon: _aiLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onSurface,
                    ),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Reclassify using AI',
            onPressed: _aiLoading ? null : _reclassifyWithAi,
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
          _EditableDetailRow(
            label: 'Category',
            value: _categoryName(),
            onTap: _openReclassify,
          ),
          _EditableDetailRow(
            label: 'Payment source',
            value: _paymentSourceLabel(),
            onTap: _openReclassify,
          ),
          _DetailRow(label: 'Type', value: _tx.type.name.toUpperCase()),
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
          if (_tx.travelProvider != null && _tx.travelProvider!.isNotEmpty)
            _DetailRow(label: 'Travel provider', value: _tx.travelProvider!),
          _DetailRow(label: 'Currency', value: _tx.currency),
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
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sms_outlined),
                  title: const Text('View original message'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _viewOriginalMessage,
                ),
                if (!_tx.excluded) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.block_outlined, color: scheme.outline),
                    title: const Text('Not a real transaction'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _exclude,
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: scheme.error),
                  title: Text(
                    'Delete',
                    style: TextStyle(color: scheme.error),
                  ),
                  trailing: Icon(Icons.chevron_right, color: scheme.error),
                  onTap: _delete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableDetailRow extends StatelessWidget {
  const _EditableDetailRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Icon(Icons.edit_outlined, size: 18, color: scheme.outline),
              ],
            ),
          ),
        ),
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
