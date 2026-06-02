import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/classify_pickers.dart';
import '../../core/widgets/original_ingest_sheet.dart';
import '../../services/app_services.dart';
import '../accounts/payment_source_widgets.dart';
import '../../services/category_service.dart';
import '../../services/payment_source_service.dart';
import 'review_repository.dart';

/// Full-screen classify / reclassify flow.
class ClassifyScreen extends StatefulWidget {
  const ClassifyScreen({
    super.key,
    required this.repository,
    required this.paymentSourceService,
    this.transaction,
    this.transactionId,
  }) : assert(
          transaction != null || transactionId != null,
          'Provide a transaction or a transactionId',
        );

  final ReviewRepository repository;
  final PaymentSourceService paymentSourceService;
  final Transaction? transaction;
  final String? transactionId;

  @override
  State<ClassifyScreen> createState() => _ClassifyScreenState();
}

class _ClassifyScreenState extends State<ClassifyScreen> {
  final _notesController = TextEditingController();
  final _itemController = TextEditingController();
  final _merchantController = TextEditingController();

  Transaction? _tx;
  List<Category> _categories = [];
  List<PaymentSource> _paymentSources = [];
  final List<String> _shoppingItems = [];
  String? _selectedCategoryId;
  String? _selectedPaymentSourceId;
  bool _saveRule = true;
  bool _loading = true;
  bool _saving = false;
  bool _aiLoading = false;
  String? _error;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('d MMM yyyy, h:mm a');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _itemController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final categories = await widget.repository.availableCategories();
      final sources = visiblePaymentSources(
        await widget.paymentSourceService.loadAll(),
      );
      final tx = widget.transaction ??
          await widget.repository.transactionById(widget.transactionId!);
      if (!mounted) return;
      if (tx == null) {
        setState(() {
          _loading = false;
          _error = 'Transaction not found. It may not have synced yet.';
        });
        return;
      }
      _notesController.text = tx.userNotes ?? '';
      _merchantController.text = tx.displayMerchant ?? '';
      _shoppingItems
        ..clear()
        ..addAll(tx.shoppingItems);
      setState(() {
        _tx = tx;
        _categories = categories;
        _paymentSources = sources;
        _selectedCategoryId = tx.categoryId;
        _selectedPaymentSourceId = tx.paymentSourceId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _addItem() {
    final value = _itemController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _shoppingItems.add(value);
      _itemController.clear();
    });
  }

  Future<void> _reclassifyWithAi() async {
    final tx = _tx;
    if (tx == null || _aiLoading) return;
    setState(() => _aiLoading = true);
    try {
      final update =
          await AppScope.of(context).aiClassifyService.suggestForForm(tx);
      if (!mounted) return;
      if (update.needsConfig) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI classify needs GEMINI_API_KEY on Cloud Functions.',
            ),
          ),
        );
        return;
      }
      if (update.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI classify failed: ${update.errorMessage}')),
        );
        return;
      }
      setState(() {
        if (update.categoryId != null) {
          _selectedCategoryId = update.categoryId;
        }
        if (update.paymentSourceId != null) {
          _selectedPaymentSourceId = update.paymentSourceId;
        }
        if (update.merchantNormalized != null) {
          _merchantController.text = update.merchantNormalized!;
        }
        if (update.userNotes != null) {
          _notesController.text = update.userNotes!;
        }
        if (update.shoppingItems.isNotEmpty) {
          _shoppingItems
            ..clear()
            ..addAll(update.shoppingItems);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI suggestions applied — review and save')),
      );
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _save() async {
    final tx = _tx;
    final categoryId = _selectedCategoryId;
    if (tx == null || categoryId == null) return;
    if (tx.unmatched && _selectedPaymentSourceId == null) return;

    final sourceChanged = _selectedPaymentSourceId != null &&
        _selectedPaymentSourceId != tx.paymentSourceId;
    final merchantName = _merchantController.text.trim();
    final merchantNormalized =
        merchantName.isEmpty ? null : merchantName;

    setState(() => _saving = true);
    try {
      await widget.repository.classify(
        transaction: tx,
        input: ClassifyInput(
          categoryId: categoryId,
          userNotes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          shoppingItems: _showShoppingList
              ? List<String>.from(_shoppingItems)
              : const [],
          saveMerchantRule: _saveRule,
          paymentSourceId: sourceChanged ? _selectedPaymentSourceId : null,
          merchantNormalized: merchantNormalized,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reclassify'),
        actions: [
          TextButton.icon(
            onPressed: _aiLoading || _loading ? null : _reclassifyWithAi,
            icon: _aiLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('Reclassify using AI'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  child: Center(
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                )
              : _buildForm(context),
    );
  }

  bool get _showShoppingList {
    final tx = _tx;
    if (tx == null) return false;
    return CategoryService.showShoppingList(
      transaction: tx,
      selectedCategoryId: _selectedCategoryId,
    );
  }

  Widget _buildForm(BuildContext context) {
    final tx = _tx!;
    final scheme = Theme.of(context).colorScheme;
    final flags = <String>[
      if (tx.unmatched) 'Unmatched',
      if (tx.ambiguous) 'Ambiguous',
      if (tx.needsClassification) 'Needs category',
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        Card(
          color: scheme.primaryContainer.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tx.displayMerchant ?? 'Unknown merchant',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      _currency.format(tx.amount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${tx.type.name.toUpperCase()} · ${_dateFormat.format(tx.timestamp)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                if (flags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.tight),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: flags
                        .map((f) => AppStatusChip(
                              label: f,
                              tone: AppStatTone.warning,
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        AppSectionHeader(title: 'Merchant'),
        TextField(
          controller: _merchantController,
          decoration: const InputDecoration(
            labelText: 'Display name',
            hintText: 'e.g. Zepto, Swiggy',
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        AppSectionHeader(
          title: 'Account',
          subtitle: tx.unmatched
              ? 'Which bank or card was this charge on?'
              : 'Change if the wrong bank or card was matched',
        ),
        PaymentSourceClassifyPicker(
          sources: _paymentSources,
          selectedId: _selectedPaymentSourceId,
          onSelected: (id) => setState(() => _selectedPaymentSourceId = id),
        ),
        const SizedBox(height: AppSpacing.section),
        AppSectionHeader(title: 'Category'),
        CategoryClassifyPicker(
          categories: _categories,
          selectedId: _selectedCategoryId,
          onSelected: (id) => setState(() => _selectedCategoryId = id),
        ),
        if (tx.merchant != null) ...[
          const SizedBox(height: AppSpacing.tight),
          CheckboxListTile(
            value: _saveRule,
            onChanged: (v) => setState(() => _saveRule = v ?? false),
            title: Text('Remember "${tx.merchant}" → this category'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        AppSectionHeader(
          title: 'Notes',
          subtitle: 'What was this for? (optional)',
        ),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'e.g. weekly groceries, gift for mom',
          ),
        ),
        if (_showShoppingList) ...[
          const SizedBox(height: AppSpacing.section),
          AppSectionHeader(
            title: 'Shopping list',
            subtitle: 'Add items bought (optional)',
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _itemController,
                  decoration: const InputDecoration(hintText: 'Add an item'),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              const SizedBox(width: AppSpacing.tight),
              IconButton.filledTonal(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (_shoppingItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.item),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _shoppingItems
                  .map(
                    (item) => InputChip(
                      label: Text(item),
                      onDeleted: () =>
                          setState(() => _shoppingItems.remove(item)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.section),
        OutlinedButton.icon(
          onPressed: () => showOriginalIngestSheet(
            context,
            localDatabase: AppScope.of(context).localDatabase,
            rawIngestId: tx.rawIngestId,
          ),
          icon: const Icon(Icons.sms_outlined),
          label: const Text('View original message'),
        ),
        const SizedBox(height: AppSpacing.item),
        FilledButton(
          onPressed: _saving ||
                  _selectedCategoryId == null ||
                  (tx.unmatched && _selectedPaymentSourceId == null)
              ? null
              : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save classification'),
        ),
      ],
    );
  }
}
