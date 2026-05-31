import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_matters/models/transaction.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import '../../services/category_service.dart';
import '../review/classify_screen.dart';
import '../review/review_repository.dart';

/// Full parsed view of a single transaction with a reclassify action.
class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.reviewRepository,
    required this.categoryService,
    this.paymentSourceName,
  });

  final Transaction transaction;
  final ReviewRepository reviewRepository;
  final CategoryService categoryService;
  final String? paymentSourceName;

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late Transaction _tx;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('EEE, d MMM yyyy · h:mm:ss a');

  @override
  void initState() {
    super.initState();
    _tx = widget.transaction;
  }

  Future<void> _reclassify() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClassifyScreen(
          repository: widget.reviewRepository,
          transaction: _tx,
        ),
      ),
    );
    if (changed == true && _tx.id != null) {
      final updated = await widget.reviewRepository.transactionById(_tx.id!);
      if (updated != null && mounted) {
        setState(() => _tx = updated);
      }
    }
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
            value: widget.paymentSourceName ??
                (_tx.unmatched ? 'Unmatched (not counted)' : '—'),
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
              if (!_tx.needsClassification &&
                  !_tx.ambiguous &&
                  !_tx.unmatched)
                AppStatusChip(label: 'Classified', tone: AppStatTone.success),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          FilledButton.icon(
            onPressed: _reclassify,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Reclassify'),
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
