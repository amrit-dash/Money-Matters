import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/auth/auth_service.dart';

/// Registers the device FCM token and routes tapped "classify" notifications.
///
/// Real remote push (APNs) requires a paid Apple Developer account. On a free
/// personal team `getToken()` may return null or throw — this service degrades
/// gracefully so the in-app "Needs your input" inbox remains the working
/// fallback. The full code path is in place for when a paid account is added.
class FcmService {
  FcmService({
    required AuthService authService,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  })  : _authService = authService,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance;

  final AuthService _authService;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  bool _handlersAttached = false;

  /// Requests notification permission and stores the device token in Firestore.
  Future<void> registerForUser() async {
    if (!_authService.isSignedIn) return;
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      // APNs token may be unavailable on a free Apple team — tolerate null.
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(token);
      }
      _messaging.onTokenRefresh.listen(_saveToken);
    } catch (e) {
      debugPrint('FcmService.registerForUser: $e (push unavailable, using inbox)');
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      final uid = _authService.requireUid();
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('fcm_tokens')
          .doc(token)
          .set({
        'token': token,
        'platform': 'ios',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FcmService._saveToken: $e');
    }
  }

  /// Wires foreground + tapped notification handling.
  ///
  /// [onClassify] is called with a transaction id when the user taps a
  /// classify notification (or one launched the app).
  void attachHandlers({required void Function(String txId) onClassify}) {
    if (_handlersAttached) return;
    _handlersAttached = true;

    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _routeIfClassify(message, onClassify),
    );

    _messaging.getInitialMessage().then((message) {
      if (message != null) _routeIfClassify(message, onClassify);
    });
  }

  void _routeIfClassify(
    RemoteMessage message,
    void Function(String txId) onClassify,
  ) {
    final data = message.data;
    final txId = (data['txId'] ?? data['transactionId'])?.toString();
    if (txId != null && txId.isNotEmpty) {
      onClassify(txId);
    }
  }
}
