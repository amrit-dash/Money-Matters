import 'package:flutter/material.dart';

import 'package:money_matters/models/category.dart';
import 'package:money_matters/models/transaction.dart';

class RelabelResult {
  const RelabelResult({
    required this.categoryId,
    this.saveMerchantRule = false,
  });

  final String categoryId;
  final bool saveMerchantRule;
}

class RelabelSheet extends StatefulWidget {
  const RelabelSheet({
    super.key,
    required this.transaction,
    required this.categories,
  });

  final Transaction transaction;
  final List<Category> categories;

  @override
  State<RelabelSheet> createState() => _RelabelSheetState();
}

class _RelabelSheetState extends State<RelabelSheet> {
  String? _selectedCategoryId;
  bool _saveRule = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.transaction.categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Relabel', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            widget.transaction.merchant ?? 'Unknown merchant',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategoryId,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: widget.categories
                .map(
                  (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedCategoryId = v),
          ),
          if (widget.transaction.merchant != null) ...[
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _saveRule,
              onChanged: (v) => setState(() => _saveRule = v ?? false),
              title: Text(
                'Remember "${widget.transaction.merchant}" → this category',
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _selectedCategoryId == null
                ? null
                : () {
                    Navigator.pop(
                      context,
                      RelabelResult(
                        categoryId: _selectedCategoryId!,
                        saveMerchantRule: _saveRule,
                      ),
                    );
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
