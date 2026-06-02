// Template for local Firebase config — DO NOT put real keys in git.
//
// Setup (from repo root):
//   flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID --platforms=ios \
//     --out=lib/core/config/firebase_options.dart --yes
//
// Or copy this file:
//   cp lib/core/config/firebase_options.example.dart lib/core/config/firebase_options.dart
//   then replace placeholders and set isConfigured = true.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const bool isConfigured = false;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Money Matters is iOS-only.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Money Matters is iOS-only. Unsupported platform: '
          '$defaultTargetPlatform',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_FIREBASE_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
    iosClientId: 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com',
    iosBundleId: 'com.amritdash.moneymatters',
  );
}
