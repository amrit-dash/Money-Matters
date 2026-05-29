import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Activates Firebase App Check for SDK traffic (Auth, Firestore, etc.).
///
/// The Shortcuts → [ingestSms] HTTP path cannot use App Check; it uses device
/// Bearer tokens instead. See [docs/APP-CHECK.md](docs/APP-CHECK.md).
class AppCheckBootstrap {
  static Future<void> activate() async {
    await FirebaseAppCheck.instance.activate(
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  }
}
