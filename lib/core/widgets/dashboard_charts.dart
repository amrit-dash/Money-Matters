import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/dashboard/dashboard_repository.dart';
import '../theme/app_theme.dart';

/// Horizontal bar chart of top categories for the selected period.
class CategorySpendBarChart extends StatelessWidget {
  const CategorySpendBarChart({
    super.key,
    required this.breakdown,
    required this.totalSpend,
    this.maxBars = 6,
  });

  final List<CategoryBreakdown> breakdown;
  final double totalSpend;
  final int maxBars;

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty || totalSpend <= 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final top = breakdown.take(maxBars).toList();
    final maxAmount = top.map((b) => b.amount).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spend by category',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.item),
            ...top.map((row) {
              final share = maxAmount <= 0 ? 0.0 : row.amount / maxAmount;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.category.name,
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          NumberFormat.compactCurrency(
                            locale: 'en_IN',
                            symbol: '₹',
                          ).format(row.amount),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: share.clamp(0.05, 1.0),
                        minHeight: 8,
                        backgroundColor:
                            scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        color: scheme.primary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Compares current period spend to the immediately prior week/month.
class PeriodComparisonCard extends StatelessWidget {
  const PeriodComparisonCard({
    super.key,
    required this.currentSpend,
    required this.priorSpend,
    required this.priorLabel,
  });

  final double currentSpend;
  final double priorSpend;
  final String priorLabel;

  @override
  Widget build(BuildContext context) {
    if (currentSpend <= 0 && priorSpend <= 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final delta = currentSpend - priorSpend;
    final pct = priorSpend <= 0
        ? null
        : ((delta / priorSpend) * 100).round();
    final trendUp = delta > 0;
    final trendIcon = delta == 0
        ? Icons.trending_flat
        : trendUp
            ? Icons.trending_up
            : Icons.trending_down;
    final trendColor = delta == 0
        ? scheme.onSurfaceVariant
        : trendUp
            ? scheme.error
            : scheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(trendIcon, color: trendColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vs $priorLabel',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    priorSpend <= 0
                        ? 'No matched spend in prior period'
                        : '${currency.format(priorSpend)} prior · '
                            '${pct == null ? '' : '${pct > 0 ? '+' : ''}$pct%'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (priorSpend > 0)
              Text(
                currency.format(delta.abs()),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: trendColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
