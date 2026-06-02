#!/usr/bin/env bash
# Write gitignored lib/core/config/firebase_options.dart from GoogleService-Info.plist.
# Used locally and in GitHub Actions (after plist is installed from secret).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="${1:-$ROOT/ios/Runner/GoogleService-Info.plist}"
OUT="${2:-$ROOT/lib/core/config/firebase_options.dart}"

if [[ ! -f "$PLIST" ]]; then
  if [[ -f "$ROOT/lib/core/config/firebase_options.example.dart" ]]; then
    cp "$ROOT/lib/core/config/firebase_options.example.dart" "$OUT"
    echo "No plist at $PLIST — copied firebase_options.example.dart for analyze-only."
    exit 0
  fi
  echo "Missing $PLIST and no firebase_options.example.dart fallback." >&2
  exit 1
fi

eval "$(python3 - "$PLIST" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as f:
    p = plistlib.load(f)

def emit(key, var):
    val = p[key]
    if not isinstance(val, str):
        raise SystemExit(f"Missing or invalid plist key: {key}")
    escaped = val.replace("'", "\\'")
    print(f"{var}='{escaped}'")

emit("API_KEY", "api_key")
emit("GOOGLE_APP_ID", "app_id")
emit("GCM_SENDER_ID", "messaging_sender_id")
emit("PROJECT_ID", "project_id")
emit("STORAGE_BUCKET", "storage_bucket")
emit("CLIENT_ID", "ios_client_id")
emit("BUNDLE_ID", "ios_bundle_id")
PY
)"

mkdir -p "$(dirname "$OUT")"
cat >"$OUT" <<EOF
// Generated from GoogleService-Info.plist — gitignored, do not commit.
// Regenerate: ./scripts/generate_firebase_options_from_plist.sh

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const bool isConfigured = true;

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
          '\$defaultTargetPlatform',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '$api_key',
    appId: '$app_id',
    messagingSenderId: '$messaging_sender_id',
    projectId: '$project_id',
    storageBucket: '$storage_bucket',
    iosClientId: '$ios_client_id',
    iosBundleId: '$ios_bundle_id',
  );
}
EOF

echo "Wrote $OUT from $PLIST"
