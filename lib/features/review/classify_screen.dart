import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/category_taxonomy.dart';
import 'package:money_matters/models/payment_source.dart';
import 'package:money_matters/models/transaction.dart';

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
  final _transferToController = TextEditingController();
  final _customTravelProviderController = TextEditingController();

  Transaction? _tx;
  List<Category> _categories = [];
  List<PaymentSource> _paymentSources = [];
  final List<String> _shoppingItems = [];
  String? _selectedTravelProvider;
  bool _travelProviderCustom = false;
  bool _serviceProviderCustom = false;
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  String? _selectedPaymentSourceId;
  bool _saveRule = true;
  bool _loading = true;
  bool _saving = false;
  bool _aiLoading = false;
  bool _formDirty = false;
  bool _aiAssisted = false;
  String? _originalMerchant;
  String? _error;

  StreamSubscription<List<Category>>? _categoriesSub;
  StreamSubscription<List<PaymentSource>>? _sourcesSub;
  StreamSubscription<Transaction?>? _transactionSub;
  bool _streamsAttached = false;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('d MMM yyyy, h:mm a');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_streamsAttached) return;
    _streamsAttached = true;

    _categoriesSub = widget.repository.watchAvailableCategories().listen(
      (categories) {
        if (!mounted) return;
        setState(() => _categories = categories);
      },
    );

    _sourcesSub = widget.paymentSourceService.watchAll().listen((sources) {
      if (!mounted) return;
      setState(
        () => _paymentSources = visiblePaymentSources(sources),
      );
    });

    final txId = widget.transaction?.id ?? widget.transactionId;
    if (txId != null) {
      _transactionSub = widget.repository.watchTransaction(txId).listen((tx) {
        if (!mounted || tx == null) return;
        _applyRemoteTransaction(tx);
      });
    }
  }

  @override
  void dispose() {
    _categoriesSub?.cancel();
    _sourcesSub?.cancel();
    _transactionSub?.cancel();
    _notesController.dispose();
    _itemController.dispose();
    _merchantController.dispose();
    _transferToController.dispose();
    _customTravelProviderController.dispose();
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
      _transferToController.text = tx.transferTo ?? '';
      if (_transferToController.text.isEmpty) {
        _maybeAutofillTransferTo(tx);
      }
      _shoppingItems
        ..clear()
        ..addAll(tx.shoppingItems);
      _initTravelProvider(tx.travelProvider);
      _initServiceProviderFromMerchant(
        categoryId: tx.categoryId,
        subcategoryId: tx.subcategoryId,
      );
      setState(() {
        _tx = tx;
        _originalMerchant = tx.merchant;
        _categories = categories;
        _paymentSources = sources;
        _selectedCategoryId = tx.categoryId;
        _selectedSubcategoryId = tx.subcategoryId;
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

  /// Applies background classification updates without clobbering in-progress edits.
  void _applyRemoteTransaction(Transaction tx) {
    if (_saving || _formDirty) {
      setState(() => _tx = tx);
      return;
    }

    final categoryChanged = tx.categoryId != _selectedCategoryId;
    final sourceChanged = tx.paymentSourceId != _selectedPaymentSourceId;
    final flagsChanged = tx.needsClassification != _tx?.needsClassification ||
        tx.ambiguous != _tx?.ambiguous ||
        tx.unmatched != _tx?.unmatched;

    if (!categoryChanged && !sourceChanged && !flagsChanged) {
      setState(() => _tx = tx);
      return;
    }

    _notesController.text = tx.userNotes ?? '';
    _merchantController.text = tx.displayMerchant ?? '';
    _transferToController.text = tx.transferTo ?? '';
    if (_transferToController.text.isEmpty) {
      _maybeAutofillTransferTo(tx);
    }
    _shoppingItems
      ..clear()
      ..addAll(tx.shoppingItems);
    _initTravelProvider(tx.travelProvider);
    _initServiceProviderFromMerchant(
      categoryId: tx.categoryId,
      subcategoryId: tx.subcategoryId,
    );
    setState(() {
      _tx = tx;
      _selectedCategoryId = tx.categoryId;
      _selectedSubcategoryId = tx.subcategoryId;
      _selectedPaymentSourceId = tx.paymentSourceId;
    });
  }

  void _initServiceProviderFromMerchant({
    String? categoryId,
    String? subcategoryId,
  }) {
    final merchant = _merchantController.text.trim();
    if (merchant.isEmpty) {
      _serviceProviderCustom = false;
      return;
    }
    final presets = serviceProvidersFor(
      categoryId ?? _selectedCategoryId,
      subcategoryId ?? _selectedSubcategoryId,
    );
    if (presets.isEmpty) {
      _serviceProviderCustom = false;
      return;
    }
    _serviceProviderCustom = !presets.any(
      (p) => p.toLowerCase() == merchant.toLowerCase(),
    );
  }

  String? get _selectedServiceProvider {
    final text = _merchantController.text.trim();
    if (text.isEmpty) return null;
    final presets =
        serviceProvidersFor(_selectedCategoryId, _selectedSubcategoryId);
    for (final preset in presets) {
      if (preset.toLowerCase() == text.toLowerCase()) return preset;
    }
    return _serviceProviderCustom ? text : null;
  }

  void _maybeAutofillTransferTo(Transaction tx) {
    if (!CategoryService.showTransferTo(
      transaction: tx,
      selectedCategoryId: _selectedCategoryId,
    )) {
      return;
    }
    if (_transferToController.text.trim().isNotEmpty) return;
    final source = tx.displayMerchant;
    if (source != null && source.isNotEmpty) {
      _transferToController.text = source;
    }
  }

  void _initTravelProvider(String? provider) {
    if (provider == null || provider.isEmpty) {
      _selectedTravelProvider = null;
      _travelProviderCustom = false;
      _customTravelProviderController.clear();
      return;
    }
    final preset = CategoryService.defaultTravelProviders
        .map((p) => p.toLowerCase())
        .toList();
    final matchIndex = preset.indexOf(provider.toLowerCase());
    if (matchIndex >= 0) {
      _selectedTravelProvider =
          CategoryService.defaultTravelProviders[matchIndex];
      _travelProviderCustom = false;
      _customTravelProviderController.clear();
    } else {
      _selectedTravelProvider = provider;
      _travelProviderCustom = true;
      _customTravelProviderController.text = provider;
    }
  }

  void _markFormDirty() => _formDirty = true;

  void _addItem() {
    final value = _itemController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _shoppingItems.add(value);
      _itemController.clear();
      _formDirty = true;
    });
  }

  Future<void> _reclassifyWithAi() async {
    final tx = _tx;
    if (tx == null || _aiLoading) return;
    setState(() => _aiLoading = true);
    try {
      final update = await AppScope.of(context).aiClassifyService.suggestForForm(
        tx,
        selectedCategoryId: _selectedCategoryId,
      );
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
        _aiAssisted = true;
        if (update.categoryId != null) {
          _formDirty = true;
          _selectedCategoryId = update.categoryId;
          if (update.subcategoryId != null) {
            _selectedSubcategoryId = update.subcategoryId;
          } else if (!CategoryService.subcategoriesFor(update.categoryId)
              .any((s) => s.id == _selectedSubcategoryId)) {
            _selectedSubcategoryId = null;
          }
        }
        if (update.subcategoryId != null && update.categoryId == null) {
          _selectedSubcategoryId = update.subcategoryId;
        }
        if (update.paymentSourceId != null) {
          _selectedPaymentSourceId = update.paymentSourceId;
        }
        if (update.merchantNormalized != null) {
          _formDirty = true;
          _merchantController.text = update.merchantNormalized!;
        }
        if (update.merchant != null && _tx != null) {
          _tx = _tx!.copyWith(merchant: update.merchant);
        } else if (update.merchantNormalized != null && _tx != null) {
          _tx = _tx!.copyWith(merchant: update.merchantNormalized);
        }
        if (update.shoppingItems.isNotEmpty) {
          _shoppingItems
            ..clear()
            ..addAll(update.shoppingItems);
        }
        if (update.travelProvider != null) {
          _initTravelProvider(update.travelProvider);
        }
        if (update.transferTo != null) {
          _transferToController.text = update.transferTo!;
        } else if (update.categoryId == CategoryService.transferCategoryId &&
            update.merchantNormalized != null) {
          _transferToController.text = update.merchantNormalized!;
        }
      });
      if (update.suggestedCategoryName != null &&
          update.suggestedCategoryId != null &&
          update.categoryId == null) {
        _offerSuggestedCategory(
          id: update.suggestedCategoryId!,
          name: update.suggestedCategoryName!,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI suggestions applied — review and save'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _offerSuggestedCategory({
    required String id,
    required String name,
  }) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('AI suggests a new category: $name'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Add',
          onPressed: () => _createSuggestedCategory(id: id, name: name),
        ),
      ),
    );
  }

  Future<void> _createSuggestedCategory({
    required String id,
    required String name,
  }) async {
    final created = await AppScope.of(context)
        .categoryService
        .createUserCategory(id: id, name: name);
    if (!mounted) return;
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create category')),
      );
      return;
    }
    final categories = await widget.repository.availableCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _selectedCategoryId = created.id;
      _selectedSubcategoryId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added category "${created.name}"')),
    );
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
    final rawMerchantOverride = merchantName.isEmpty
        ? null
        : merchantName.toUpperCase();
    final shouldUpdateMerchant = rawMerchantOverride != null &&
        rawMerchantOverride != (_originalMerchant ?? '').toUpperCase();

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
          travelProvider: _travelProviderForSave,
          subcategoryId: _subcategoryForSave,
          transferTo: _transferToForSave,
          saveMerchantRule: _saveRule,
          paymentSourceId: sourceChanged ? _selectedPaymentSourceId : null,
          merchantNormalized: merchantNormalized,
          merchant: shouldUpdateMerchant ? rawMerchantOverride : null,
          classifiedBy: _aiAssisted ? ClassifiedBy.llm : ClassifiedBy.user,
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _aiLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _loading ? null : _reclassifyWithAi,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                    label: const Text('Use AI'),
                  ),
          ),
          if (_formDirty && !_loading && _error == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.save_outlined),
                tooltip: 'Save',
                onPressed: _saving ? null : _save,
              ),
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

  bool get _showSubcategoryPicker {
    final tx = _tx;
    if (tx == null) return false;
    return CategoryService.showSubcategoryPicker(
      transaction: tx,
      selectedCategoryId: _selectedCategoryId,
    );
  }

  /// Empty string clears subcategory when parent category has none.
  String? get _subcategoryForSave {
    if (!_showSubcategoryPicker) return '';
    return _selectedSubcategoryId ?? '';
  }

  bool get _showTravelProvider {
    final tx = _tx;
    if (tx == null) return false;
    return CategoryService.showTravelProvider(
      transaction: tx,
      selectedCategoryId: _selectedCategoryId,
    );
  }

  bool get _showTransferTo {
    final tx = _tx;
    if (tx == null) return false;
    return CategoryService.showTransferTo(
      transaction: tx,
      selectedCategoryId: _selectedCategoryId,
    );
  }

  /// Value to persist: recipient string, empty to clear, or omit when hidden.
  String? get _transferToForSave {
    if (!_showTransferTo) return '';
    return _transferToController.text.trim();
  }

  /// Value to persist: provider string, empty to clear, or omit when unchanged.
  String? get _travelProviderForSave {
    if (!_showTravelProvider) return '';
    if (_travelProviderCustom) {
      return _customTravelProviderController.text.trim();
    }
    return _selectedTravelProvider;
  }

  String? get _merchantNameForRule {
    final fromField = _merchantController.text.trim();
    if (fromField.isNotEmpty) return fromField.toUpperCase();
    return _tx?.merchant;
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
        AppSectionHeader(title: 'Paid to'),
        TextField(
          controller: _merchantController,
          onChanged: (_) => _markFormDirty(),
          decoration: const InputDecoration(
            labelText: 'Display name',
            hintText: 'e.g. Zepto, Swiggy',
          ),
        ),
        if (_showTransferTo) ...[
          const SizedBox(height: AppSpacing.item),
          TextField(
            controller: _transferToController,
            onChanged: (_) => _markFormDirty(),
            decoration: const InputDecoration(
              labelText: 'Transfer to',
              hintText: 'e.g. John, HDFC Savings',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        AppSectionHeader(title: 'Category'),
        CategoryClassifyPicker(
          categories: _categories,
          selectedId: _selectedCategoryId,
          onSelected: (id) => setState(() {
            _markFormDirty();
            final categoryChanged = id != _selectedCategoryId;
            _selectedCategoryId = id;
            if (!CategoryService.subcategoriesFor(id)
                .any((s) => s.id == _selectedSubcategoryId)) {
              _selectedSubcategoryId = null;
            }
            if (categoryChanged) {
              _merchantController.clear();
              _serviceProviderCustom = false;
            }
            if (_tx != null) {
              _maybeAutofillTransferTo(_tx!);
            }
          }),
        ),
        if (_merchantNameForRule != null) ...[
          const SizedBox(height: AppSpacing.tight),
          CheckboxListTile(
            value: _saveRule,
            onChanged: (v) => setState(() => _saveRule = v ?? false),
            title: Text('Remember "${_merchantNameForRule!}" → this category'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
        if (_showSubcategoryPicker && _selectedCategoryId != null) ...[
          const SizedBox(height: AppSpacing.item),
          SubcategoryClassifyPicker(
            categoryId: _selectedCategoryId!,
            selectedSubcategoryId: _selectedSubcategoryId,
            onSelected: (id) => setState(() {
              _markFormDirty();
              if (id != _selectedSubcategoryId) {
                _merchantController.clear();
                _serviceProviderCustom = false;
              }
              _selectedSubcategoryId = id;
            }),
            selectedServiceProvider: _selectedServiceProvider,
            serviceProviderCustom: _serviceProviderCustom,
            customServiceProviderController: _merchantController,
            onServiceProviderSelected: (provider) => setState(() {
              _markFormDirty();
              _serviceProviderCustom = false;
              _merchantController.text = provider;
            }),
            onServiceProviderCustomMode: () => setState(() {
              _markFormDirty();
              _serviceProviderCustom = true;
              _merchantController.clear();
            }),
          ),
        ],
        if (_showTravelProvider) ...[
          const SizedBox(height: AppSpacing.section),
          AppSectionHeader(
            title: 'Ride / travel provider',
            subtitle: 'Which app or service? (optional)',
          ),
          TravelProviderPicker(
            selectedProvider: _selectedTravelProvider,
            customMode: _travelProviderCustom,
            customController: _customTravelProviderController,
            onPresetSelected: (provider) => setState(() {
              _markFormDirty();
              _travelProviderCustom = false;
              _selectedTravelProvider = provider;
              _customTravelProviderController.clear();
            }),
            onCustomMode: () => setState(() {
              _markFormDirty();
              _travelProviderCustom = true;
              _selectedTravelProvider = null;
            }),
          ),
        ],
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
                      onDeleted: () => setState(() {
                        _shoppingItems.remove(item);
                        _markFormDirty();
                      }),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
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
          onSelected: (id) => setState(() {
            _markFormDirty();
            _selectedPaymentSourceId = id;
          }),
        ),
        const SizedBox(height: AppSpacing.section),
        AppSectionHeader(
          title: 'Notes',
          subtitle: 'What was this for? (optional)',
        ),
        TextField(
          controller: _notesController,
          onChanged: (_) => _markFormDirty(),
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'e.g. weekly groceries, gift for mom',
          ),
        ),
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
