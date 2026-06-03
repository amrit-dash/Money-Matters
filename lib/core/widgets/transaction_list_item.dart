import 'package:flutter/material.dart';

import 'app_ui.dart';

/// Three-row transaction row used across dashboard, category, source, and period lists.
class TransactionListItem extends StatelessWidget {
  const TransactionListItem({
    super.key,
    required this.dateLabel,
    required this.categoryName,
    required this.merchantName,
    required this.amountLabel,
    required this.paymentSourceLabel,
    required this.onTap,
    this.isCredit = false,
  });

  final String dateLabel;
  final String categoryName;
  final String merchantName;
  final String amountLabel;
  final String paymentSourceLabel;
  final VoidCallback onTap;
  final bool isCredit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final dateColor = scheme.primary.withValues(alpha: 0.85);
    final categoryColor = scheme.secondary.withValues(alpha: 0.9);
    final amountColor = isCredit
        ? scheme.primary
        : scheme.tertiary.withValues(alpha: 0.95);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: dateColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                categoryName,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: categoryColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  merchantName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                amountLabel,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            paymentSourceLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) + 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
