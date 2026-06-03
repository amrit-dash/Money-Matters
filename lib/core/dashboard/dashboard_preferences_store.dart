import 'package:shared_preferences/shared_preferences.dart';

/// Persists overview dashboard layout (calendar vs list).
class DashboardPreferencesStore {
  DashboardPreferencesStore({SharedPreferences? preferences})
      : _preferencesFuture = preferences != null
            ? Future.value(preferences)
            : SharedPreferences.getInstance();

  static const _layoutKey = 'overview_layout';

  final Future<SharedPreferences> _preferencesFuture;

  /// `calendar` or `list`; defaults to calendar for new users.
  Future<String> loadLayout() async {
    final prefs = await _preferencesFuture;
    return prefs.getString(_layoutKey) ?? 'calendar';
  }

  Future<void> saveLayout(String layout) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(_layoutKey, layout);
  }
}
