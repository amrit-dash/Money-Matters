import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_matters/models/category.dart';

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
    final accents = chartAccentColors(scheme);
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
            ...top.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              final share = maxAmount <= 0 ? 0.0 : row.amount / maxAmount;
              final barColor = accents[index % accents.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                        color: barColor,
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

/// Credits (income), spend, and saved (net) for the selected period.
class CreditsSpendSavedChart extends StatelessWidget {
  const CreditsSpendSavedChart({
    super.key,
    required this.totalIncome,
    required this.totalSpend,
    required this.saved,
  });

  final double totalIncome;
  final double totalSpend;
  final double saved;

  @override
  Widget build(BuildContext context) {
    if (totalIncome <= 0 && totalSpend <= 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final currency = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');
    final maxVal = [totalIncome, totalSpend, saved.abs()]
        .fold(0.0, (a, b) => a > b ? a : b);

    Widget bar(String label, double value, Color color) {
      final share = maxVal <= 0 ? 0.0 : (value.abs() / maxVal).clamp(0.05, 1.0);
      return Expanded(
        child: Column(
          children: [
            Text(
              currency.format(value),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: share,
                  widthFactor: 0.55,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Credits vs spend vs saved',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.item),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  bar('Credits', totalIncome, scheme.primary),
                  bar('Spend', totalSpend, scheme.error),
                  bar(
                    'Saved',
                    saved,
                    saved >= 0 ? scheme.tertiary : scheme.errorContainer,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Donut chart of category spend share.
class CategorySpendPieChart extends StatelessWidget {
  const CategorySpendPieChart({
    super.key,
    required this.breakdown,
    required this.totalSpend,
    this.maxSlices = 6,
  });

  final List<CategoryBreakdown> breakdown;
  final double totalSpend;
  final int maxSlices;

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty || totalSpend <= 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final accents = chartAccentColors(scheme);
    final slices = breakdown.take(maxSlices).toList();
    final otherAmount = breakdown
        .skip(maxSlices)
        .fold(0.0, (sum, row) => sum + row.amount);
    if (otherAmount > 0) {
      slices.add(
        CategoryBreakdown(
          category: const Category(id: '_other', name: 'Other'),
          amount: otherAmount,
          transactionCount: 0,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category share',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.item),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: _PieChartPainter(
                      values: slices.map((s) => s.amount).toList(),
                      colors: [
                        for (var i = 0; i < slices.length; i++)
                          accents[i % accents.length],
                      ],
                      holeColor: scheme.surface,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < slices.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: accents[i % accents.length],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  slices[i].category.name,
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${(slices[i].shareOf(totalSpend) * 100).toStringAsFixed(0)}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  _PieChartPainter({
    required this.values,
    required this.colors,
    required this.holeColor,
  });

  final List<double> values;
  final List<Color> colors;
  final Color holeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    var startAngle = -math.pi / 2;

    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.fill,
      );
      startAngle += sweep;
    }

    canvas.drawCircle(center, radius * 0.55, Paint()..color = holeColor);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.colors != colors ||
      oldDelegate.holeColor != holeColor;
}

/// Line trend of spend, income, and saved across recent months.
class MonthlyTrendLineChart extends StatelessWidget {
  const MonthlyTrendLineChart({
    super.key,
    required this.summaries,
  });

  final List<PeriodSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.length < 2) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final labels = summaries.map((s) {
      final short = DateFormat('MMM').format(s.start);
      return short;
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly trend',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.item),
            SizedBox(
              height: 160,
              child: CustomPaint(
                painter: _MultiLineChartPainter(
                  series: [
                    _LineSeries(
                      color: scheme.error,
                      values: summaries.map((s) => s.totalSpend).toList(),
                    ),
                    _LineSeries(
                      color: scheme.primary,
                      values: summaries.map((s) => s.totalIncome).toList(),
                    ),
                    _LineSeries(
                      color: scheme.tertiary,
                      values: summaries.map((s) => s.net).toList(),
                    ),
                  ],
                  labels: labels,
                  gridColor: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: AppSpacing.tight),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _LegendDot(color: scheme.primary, label: 'Credits'),
                _LegendDot(color: scheme.error, label: 'Spend'),
                _LegendDot(color: scheme.tertiary, label: 'Saved'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LineSeries {
  const _LineSeries({required this.color, required this.values});

  final Color color;
  final List<double> values;
}

class _MultiLineChartPainter extends CustomPainter {
  _MultiLineChartPainter({
    required this.series,
    required this.labels,
    required this.gridColor,
  });

  final List<_LineSeries> series;
  final List<String> labels;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || series.first.values.isEmpty) return;

    const padLeft = 8.0;
    const padRight = 8.0;
    const padTop = 8.0;
    const padBottom = 20.0;
    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;

    final allValues = series.expand((s) => s.values).toList();
    var minY = allValues.reduce(math.min);
    var maxY = allValues.reduce(math.max);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final yRange = maxY - minY;

    double xFor(int index, int count) {
      if (count <= 1) return padLeft + chartW / 2;
      return padLeft + (index / (count - 1)) * chartW;
    }

    double yFor(double value) =>
        padTop + chartH - ((value - minY) / yRange) * chartH;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(padLeft, padTop + chartH),
      Offset(padLeft + chartW, padTop + chartH),
      gridPaint,
    );

    final count = series.first.values.length;
    for (var s = 0; s < series.length; s++) {
      final line = series[s];
      final path = Path();
      for (var i = 0; i < line.values.length; i++) {
        final point = Offset(xFor(i, count), yFor(line.values[i]));
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line.color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
      for (var i = 0; i < line.values.length; i++) {
        canvas.drawCircle(
          Offset(xFor(i, count), yFor(line.values[i])),
          3,
          Paint()..color = line.color,
        );
      }
    }

    final textStyle = TextStyle(
      color: gridColor.withValues(alpha: 0.9),
      fontSize: 10,
    );
    for (var i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(xFor(i, count) - tp.width / 2, padTop + chartH + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MultiLineChartPainter oldDelegate) => true;
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
            : scheme.tertiary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: trendColor.withValues(alpha: 0.15),
              child: Icon(trendIcon, color: trendColor, size: 24),
            ),
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
