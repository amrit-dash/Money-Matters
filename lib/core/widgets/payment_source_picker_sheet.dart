import 'package:flutter/material.dart';

import '../../features/accounts/payment_source_widgets.dart';
import '../../models/payment_source.dart';
import '../theme/app_theme.dart';

/// Bottom sheet to pick a bank or card for a transaction.
Future<PaymentSource?> showPaymentSourcePickerSheet(
  BuildContext context, {
  required List<PaymentSource> sources,
  String? selectedId,
  String title = 'Payment source',
}) async {
  final visible = visiblePaymentSources(sources);
  if (visible.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add a bank or card in Accounts first.')),
    );
    return null;
  }

  final banks = visible.where((s) => s.type == PaymentSourceType.bank).toList();
  final cards = visible.where((s) => s.type == PaymentSourceType.card).toList();

  return showModalBottomSheet<PaymentSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      Widget section(String heading, IconData icon, List<PaymentSource> items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.item,
                AppSpacing.page,
                AppSpacing.tight,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: Theme.of(ctx).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(heading, style: Theme.of(ctx).textTheme.labelLarge),
                ],
              ),
            ),
            ...items.map((source) {
              final label = source.last4 != null
                  ? '${source.name} ···· ${source.last4}'
                  : source.name;
              final selected = source.id == selectedId;
              return ListTile(
                leading: Icon(
                  source.type == PaymentSourceType.card
                      ? Icons.credit_card_outlined
                      : Icons.account_balance_outlined,
                ),
                title: Text(label),
                subtitle: Text(
                  source.type == PaymentSourceType.card ? 'Card' : 'Bank account',
                ),
                trailing: selected
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(ctx, source),
              );
            }),
          ],
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.tight,
                AppSpacing.page,
                AppSpacing.item,
              ),
              child: Text(
                title,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  section('Bank accounts', Icons.account_balance_outlined, banks),
                  section('Cards', Icons.credit_card_outlined, cards),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
