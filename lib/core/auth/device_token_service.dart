import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

/// Registers the device ingest Bearer secret in Firestore for [ingestSms] auth.
class DeviceTokenService {
  DeviceTokenService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _random = Random.secure();

  /// Creates a cryptographically random bearer secret (hex).
  String generateToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String hashToken(String token) {
    return sha256.convert(utf8.encode(token)).toString();
  }

  /// Writes users/{uid}/device_tokens/{deviceId} if missing or token rotated.
  Future<void> registerDeviceToken({
    required String uid,
    required String deviceId,
    required String rawToken,
    String label = 'iPhone',
  }) async {
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('device_tokens')
        .doc(deviceId);

    await ref.set({
      'tokenHash': hashToken(rawToken),
      'createdAt': FieldValue.serverTimestamp(),
      'label': label,
    });
  }
}
