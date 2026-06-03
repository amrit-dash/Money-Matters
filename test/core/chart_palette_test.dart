import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/core/theme/app_accent.dart';
import 'package:money_matters/core/theme/app_theme.dart';
import 'package:money_matters/core/theme/chart_palette.dart';

void main() {
  test('chart palettes differ by accent seed', () {
    final teal = ChartPaletteBuilder.fromSeed(
      AppAccent.teal.seedColor,
      Brightness.dark,
    );
    final rose = ChartPaletteBuilder.fromSeed(
      AppAccent.rose.seedColor,
      Brightness.dark,
    );
    expect(teal.first, isNot(equals(rose.first)));
  });

  test('dark palettes are lighter than light for the same accent', () {
    final dark = ChartPaletteBuilder.fromSeed(
      AppAccent.amber.seedColor,
      Brightness.dark,
    );
    final light = ChartPaletteBuilder.fromSeed(
      AppAccent.amber.seedColor,
      Brightness.light,
    );
    final darkAvg = _averageLightness(dark);
    final lightAvg = _averageLightness(light);
    expect(darkAvg, greaterThan(lightAvg));
  });

  test('buildAppTheme attaches chart palette extension', () {
    final theme = buildAppTheme(
      seedColor: AppAccent.indigo.seedColor,
      brightness: Brightness.light,
    );
    final palette = theme.extension<ChartPaletteTheme>();
    expect(palette, isNotNull);
    expect(palette!.colors, hasLength(ChartPaletteTheme.sliceCount));
    expect(chartAccentColors(theme), palette.colors);
  });

  test('slice hues are spread around the accent anchor', () {
    final colors = ChartPaletteBuilder.fromSeed(
      AppAccent.violet.seedColor,
      Brightness.dark,
    );
    final hues = colors
        .map((c) => HSLColor.fromColor(c).hue)
        .toList();
    final minGap = _minCircularHueGap(hues);
    expect(minGap, greaterThan(25));
  });
}

double _averageLightness(List<Color> colors) {
  final sum = colors
      .map((c) => HSLColor.fromColor(c).lightness)
      .fold(0.0, (a, b) => a + b);
  return sum / colors.length;
}

double _minCircularHueGap(List<double> hues) {
  if (hues.length < 2) return 360;
  var minGap = 360.0;
  for (var i = 0; i < hues.length; i++) {
    for (var j = i + 1; j < hues.length; j++) {
      final diff = (hues[i] - hues[j]).abs();
      final gap = diff > 180 ? 360 - diff : diff;
      if (gap < minGap) minGap = gap;
    }
  }
  return minGap;
}
