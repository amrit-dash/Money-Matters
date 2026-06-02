import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/core/theme/app_accent.dart';
import 'package:money_matters/core/theme/theme_preferences_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ThemePreferencesStore', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('defaults to system theme and teal accent', () async {
      final store = ThemePreferencesStore(preferences: prefs);

      expect(await store.loadThemeMode(), ThemeMode.system);
      expect(await store.loadAccent(), AppAccent.teal);
    });

    test('persists theme mode and accent', () async {
      final store = ThemePreferencesStore(preferences: prefs);

      await store.saveThemeMode(ThemeMode.dark);
      await store.saveAccent(AppAccent.rose);

      expect(await store.loadThemeMode(), ThemeMode.dark);
      expect(await store.loadAccent(), AppAccent.rose);
    });

    test('falls back to teal for unknown accent id', () async {
      await prefs.setString('theme_accent', 'unknown');
      final store = ThemePreferencesStore(preferences: prefs);

      expect(await store.loadAccent(), AppAccent.teal);
    });
  });
}
