import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

/// Maps daily spend to accent shades — log-scaled so ₹100 vs ₹20,000 differ
/// clearly while similar high amounts stay closer together.
Color spendHeatmapColor(ColorScheme scheme, double amount, double maxAmount) {
  if (amount <= 0 || maxAmount <= 0) {
    return scheme.surfaceContainerHighest.withValues(alpha: 0.55);
  }
  final t = (math.log(amount + 1) / math.log(maxAmount + 1)).clamp(0.0, 1.0);
  return Color.lerp(
    scheme.primaryContainer.withValues(alpha: 0.4),
    scheme.primary,
    t,
  )!;
}

Color spendHeatmapTextColor(ColorScheme scheme, double amount, double maxAmount) {
  if (amount <= 0 || maxAmount <= 0) {
    return scheme.onSurface;
  }
  final t = (math.log(amount + 1) / math.log(maxAmount + 1)).clamp(0.0, 1.0);
  return t >= 0.55 ? scheme.onPrimary : scheme.onSurface;
}

/// Month grid with spend heatmap and optional day selection.
class OverviewSpendCalendar extends StatelessWidget {
  const OverviewSpendCalendar({
    super.key,
    required this.month,
    required this.dailySpend,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final Map<DateTime, double> dailySpend;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  DateTime get _monthStart => DateTime(month.year, month.month);

  int get _daysInMonth => DateTime(month.year, month.month + 1, 0).day;

  double get _maxSpend {
    if (dailySpend.isEmpty) return 0;
    return dailySpend.values.reduce(math.max);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return _isSameDay(day, now);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final monthLabel = DateFormat('MMMM yyyy').format(_monthStart);
    final maxSpend = _maxSpend;

    final firstWeekday = _monthStart.weekday;
    final leadingEmpty = firstWeekday - 1;
    final totalCells = leadingEmpty + _daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous month',
                  onPressed: onPreviousMonth,
                ),
                Expanded(
                  child: Text(
                    monthLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next month',
                  onPressed: onNextMonth,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.item),
            Row(
              children: [
                for (final label in _weekdayLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.tight),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellHeight = constraints.maxHeight / rowCount;

                  return Column(
                    children: [
                      for (var row = 0; row < rowCount; row++)
                        SizedBox(
                          height: cellHeight,
                          child: Row(
                            children: [
                              for (var col = 0; col < 7; col++)
                                Expanded(
                                  child: _buildCell(
                                    context,
                                    row: row,
                                    col: col,
                                    leadingEmpty: leadingEmpty,
                                    maxSpend: maxSpend,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(
    BuildContext context, {
    required int row,
    required int col,
    required int leadingEmpty,
    required double maxSpend,
  }) {
    final index = row * 7 + col;
    final dayNumber = index - leadingEmpty + 1;
    if (dayNumber < 1 || dayNumber > _daysInMonth) {
      return const SizedBox.shrink();
    }

    final day = DateTime(month.year, month.month, dayNumber);
    final spend = dailySpend[day] ?? 0;
    final scheme = Theme.of(context).colorScheme;
    final isSelected =
        selectedDate != null && _isSameDay(day, selectedDate!);
    final isToday = _isToday(day);
    final bg = spendHeatmapColor(scheme, spend, maxSpend);
    final fg = spendHeatmapTextColor(scheme, spend, maxSpend);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onDateSelected(day),
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(
                color: isSelected
                    ? scheme.primary
                    : isToday
                        ? scheme.outline
                        : Colors.transparent,
                width: isSelected ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$dayNumber',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
