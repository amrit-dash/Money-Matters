import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/core/dashboard/dashboard_preferences_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DashboardPreferencesStore', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('defaults to calendar layout', () async {
      final store = DashboardPreferencesStore(preferences: prefs);
      expect(await store.loadLayout(), 'calendar');
    });

    test('persists layout preference', () async {
      final store = DashboardPreferencesStore(preferences: prefs);

      await store.saveLayout('list');
      expect(await store.loadLayout(), 'list');

      await store.saveLayout('calendar');
      expect(await store.loadLayout(), 'calendar');
    });
  });
}
