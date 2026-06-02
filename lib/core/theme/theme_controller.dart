import 'package:flutter/material.dart';

import 'app_accent.dart';
import 'app_theme.dart';
import 'theme_preferences_store.dart';

/// Holds active theme mode + accent and rebuilds [MaterialApp] on change.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemePreferencesStore? store})
      : _store = store ?? ThemePreferencesStore();

  final ThemePreferencesStore _store;

  ThemeMode _themeMode = ThemeMode.system;
  AppAccent _accent = AppAccent.teal;

  ThemeMode get themeMode => _themeMode;
  AppAccent get accent => _accent;

  ThemeData get lightTheme =>
      buildAppTheme(seedColor: _accent.seedColor, brightness: Brightness.light);

  ThemeData get darkTheme =>
      buildAppTheme(seedColor: _accent.seedColor, brightness: Brightness.dark);

  Future<void> load() async {
    _themeMode = await _store.loadThemeMode();
    _accent = await _store.loadAccent();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _store.saveThemeMode(mode);
  }

  Future<void> setAccent(AppAccent accent) async {
    if (_accent == accent) return;
    _accent = accent;
    notifyListeners();
    await _store.saveAccent(accent);
  }
}
