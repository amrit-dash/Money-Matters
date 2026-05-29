import 'package:shared_preferences/shared_preferences.dart';

/// Persists ingest device id + bearer token per Firebase user (Keychain-like).
class DeviceCredentialsStore {
  DeviceCredentialsStore({SharedPreferences? preferences})
      : _preferencesFuture = preferences != null
          ? Future.value(preferences)
          : SharedPreferences.getInstance();

  final Future<SharedPreferences> _preferencesFuture;

  String _deviceIdKey(String uid) => 'ingest_device_id_$uid';
  String _tokenKey(String uid) => 'ingest_token_$uid';

  Future<({String deviceId, String token})?> load(String uid) async {
    final prefs = await _preferencesFuture;
    final deviceId = prefs.getString(_deviceIdKey(uid));
    final token = prefs.getString(_tokenKey(uid));
    if (deviceId == null ||
        deviceId.isEmpty ||
        token == null ||
        token.isEmpty) {
      return null;
    }
    return (deviceId: deviceId, token: token);
  }

  Future<void> save({
    required String uid,
    required String deviceId,
    required String token,
  }) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(_deviceIdKey(uid), deviceId);
    await prefs.setString(_tokenKey(uid), token);
  }
}
