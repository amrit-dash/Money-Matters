import 'package:flutter/material.dart';

/// Consistent spacing scale used across screens.
abstract final class AppSpacing {
  static const page = 20.0;
  static const section = 24.0;
  static const item = 12.0;
  static const tight = 8.0;
}

/// Shared corner radii — cards use 16px per product spec.
abstract final class AppRadii {
  static const card = 16.0;
  static const control = 12.0;
  static const badge = 12.0;
  static const chip = 999.0;
}

/// Stat / chip semantic tones mapped to [ColorScheme] containers.
enum AppStatTone { neutral, success, warning, error }

(Color background, Color foreground) appToneColors(
  ColorScheme scheme,
  AppStatTone tone,
) {
  return switch (tone) {
    AppStatTone.success => (scheme.primaryContainer, scheme.onPrimaryContainer),
    AppStatTone.warning => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    AppStatTone.error => (scheme.errorContainer, scheme.onErrorContainer),
    AppStatTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
  };
}

/// Categorical chart colors — spaced across the hue wheel so pie slices and
/// bars stay distinguishable on warm dark surfaces (not derived from
/// [ColorScheme] primary/secondary, which collapse to similar browns).
const _chartPaletteLight = <Color>[
  Color(0xFFD35400),
  Color(0xFF0E7C86),
  Color(0xFF2D6A4F),
  Color(0xFF6C4AB6),
  Color(0xFFB8860B),
  Color(0xFFC0392B),
  Color(0xFF1F6FAD),
  Color(0xFFAD1457),
];

const _chartPaletteDark = <Color>[
  Color(0xFFF4A261),
  Color(0xFF4ECDC4),
  Color(0xFF95D5B2),
  Color(0xFFB8A9E8),
  Color(0xFFFFD166),
  Color(0xFFF28482),
  Color(0xFF7EB8DA),
  Color(0xFFE07A9F),
];

/// Distinct hues for category charts (pie, bars, analytics rows).
List<Color> chartAccentColors(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark
        ? _chartPaletteDark
        : _chartPaletteLight;

Color categoryAccentColor(ColorScheme scheme, int index) {
  final accents = chartAccentColors(scheme);
  return accents[index % accents.length];
}

/// Builds a Material 3 theme from a seed color and brightness.
ThemeData buildAppTheme({
  required Color seedColor,
  Brightness brightness = Brightness.light,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );

  final isDark = brightness == Brightness.dark;
  final baseText = isDark
      ? Typography.material2021(platform: TargetPlatform.iOS).white
      : Typography.material2021(platform: TargetPlatform.iOS).black;

  final textTheme = baseText.copyWith(
    titleLarge: baseText.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    titleMedium: baseText.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
    ),
    headlineSmall: baseText.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    headlineMedium: baseText.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.card),
    side: BorderSide(
      color: scheme.outlineVariant.withValues(alpha: 0.65),
    ),
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: brightness,
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: cardShape,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.item),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      tileColor: scheme.surfaceContainerLow,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: AppSpacing.section,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: scheme.surfaceContainerHighest,
      color: scheme.primary,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        side: BorderSide(color: scheme.outline),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: textTheme.labelLarge),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}
