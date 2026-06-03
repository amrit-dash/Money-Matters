import 'package:flutter/material.dart';

/// Categorical colors for analytics charts, keyed to accent seed + brightness.
@immutable
class ChartPaletteTheme extends ThemeExtension<ChartPaletteTheme> {
  const ChartPaletteTheme({required this.colors});

  final List<Color> colors;

  static const sliceCount = 8;

  @override
  ChartPaletteTheme copyWith({List<Color>? colors}) =>
      ChartPaletteTheme(colors: colors ?? this.colors);

  @override
  ChartPaletteTheme lerp(ThemeExtension<ChartPaletteTheme>? other, double t) {
    if (other is! ChartPaletteTheme ||
        colors.length != other.colors.length) {
      return this;
    }
    return ChartPaletteTheme(
      colors: [
        for (var i = 0; i < colors.length; i++)
          Color.lerp(colors[i], other.colors[i], t)!,
      ],
    );
  }
}

/// Builds distinguishable slice colors anchored on [seedColor].
abstract final class ChartPaletteBuilder {
  static const _goldenAngle = 137.508;

  static const _lightnessDeltas = [
    -0.06,
    0.0,
    0.06,
    -0.03,
    0.03,
    -0.05,
    0.05,
    0.0,
  ];

  static const _saturationDeltas = [
    0.0,
    0.06,
    -0.04,
    0.08,
    -0.06,
    0.04,
    -0.02,
    0.05,
  ];

  static List<Color> fromSeed(Color seedColor, Brightness brightness) {
    final anchor = HSLColor.fromColor(seedColor);
    final isDark = brightness == Brightness.dark;
    final baseSaturation = isDark ? 0.58 : 0.72;
    final baseLightness = isDark ? 0.70 : 0.45;
    final minLightness = isDark ? 0.58 : 0.32;
    final maxLightness = isDark ? 0.82 : 0.58;

    return List.generate(ChartPaletteTheme.sliceCount, (i) {
      final hue = (anchor.hue + _goldenAngle * i) % 360;
      final saturation = (baseSaturation + _saturationDeltas[i]).clamp(0.45, 0.88);
      final lightness = (baseLightness + _lightnessDeltas[i]).clamp(
        minLightness,
        maxLightness,
      );
      return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
    });
  }
}
