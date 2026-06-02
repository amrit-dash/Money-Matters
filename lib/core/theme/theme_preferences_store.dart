import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_accent.dart';

/// Persists theme mode and accent seed locally.
class ThemePreferencesStore {
  ThemePreferencesStore({SharedPreferences? preferences})
      : _preferencesFuture = preferences != null
            ? Future.value(preferences)
            : SharedPreferences.getInstance();

  static const _themeModeKey = 'theme_mode';
  static const _accentKey = 'theme_accent';

  final Future<SharedPreferences> _preferencesFuture;

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await _preferencesFuture;
    return _themeModeFromString(prefs.getString(_themeModeKey));
  }

  Future<AppAccent> loadAccent() async {
    final prefs = await _preferencesFuture;
    return AppAccent.fromId(prefs.getString(_accentKey));
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(_themeModeKey, _themeModeToString(mode));
  }

  Future<void> saveAccent(AppAccent accent) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(_accentKey, accent.id);
  }

  static ThemeMode _themeModeFromString(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String _themeModeToString(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
