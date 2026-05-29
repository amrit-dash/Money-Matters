#!/usr/bin/env bash
# Pre-flight checks before installing Money Matters on a physical iPhone.
#
# Usage: ./scripts/verify_setup.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PASS=0
WARN=0
FAIL=0

ok()   { echo "  ✓ $1"; PASS=$((PASS + 1)); }
warn() { echo "  ⚠ $1"; WARN=$((WARN + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "Money Matters — setup verification"
echo "=================================="

echo ""
echo "[Flutter]"
if command -v flutter >/dev/null 2>&1; then
  ok "flutter on PATH ($(flutter --version 2>/dev/null | head -1))"
else
  fail "flutter not found — install Flutter SDK"
fi

echo ""
echo "[iOS toolchain]"
if xcodebuild -version >/dev/null 2>&1; then
  ok "Xcode: $(xcodebuild -version 2>/dev/null | head -1)"
else
  fail "Xcode not available — install from App Store; run xcode-select"
fi

if command -v pod >/dev/null 2>&1; then
  ok "CocoaPods: $(pod --version 2>/dev/null)"
else
  fail "CocoaPods not installed — gem install cocoapods"
fi

echo ""
echo "[Firebase — Flutter app]"
if [[ -f ios/Runner/GoogleService-Info.plist ]]; then
  ok "GoogleService-Info.plist present"
else
  fail "Missing ios/Runner/GoogleService-Info.plist — download from Firebase Console"
fi

if [[ -f lib/core/config/firebase_options.dart ]]; then
  if grep -q 'isConfigured = false' lib/core/config/firebase_options.dart; then
    fail "firebase_options.dart is placeholder — run flutterfire configure"
  elif grep -q 'isConfigured = true' lib/core/config/firebase_options.dart; then
    ok "firebase_options.dart configured"
  else
    warn "firebase_options.dart exists but isConfigured flag unclear"
  fi
else
  fail "Missing lib/core/config/firebase_options.dart"
fi

echo ""
echo "[Firebase — backend]"
FIREBASERC="${ROOT}/firebase/.firebaserc"
if [[ -f "${FIREBASERC}" ]]; then
  if grep -q 'YOUR_FIREBASE_PROJECT_ID' "${FIREBASERC}"; then
    fail "firebase/.firebaserc still has placeholder project ID"
  else
    ok "firebase/.firebaserc project ID set"
  fi
else
  fail "Missing firebase/.firebaserc"
fi

if command -v firebase >/dev/null 2>&1 || command -v npx >/dev/null 2>&1; then
  ok "firebase CLI available (firebase or npx)"
else
  warn "firebase CLI not found — npm install -g firebase-tools"
fi

if [[ -d firebase/functions/node_modules ]]; then
  ok "firebase/functions dependencies installed"
else
  warn "Run: cd firebase && npm ci"
fi

echo ""
echo "[Optional]"
if [[ -f .env ]]; then
  ok ".env present (local notes)"
else
  warn "No .env — copy from .env.example if you want local env notes"
fi

echo ""
echo "=================================="
echo "Passed: ${PASS}  Warnings: ${WARN}  Failed: ${FAIL}"

if [[ ${FAIL} -gt 0 ]]; then
  echo ""
  echo "Fix failures above, then see docs/SETUP-IPHONE.md"
  exit 1
fi

echo ""
echo "Ready for device install. Next: docs/SETUP-IPHONE.md → Path A or B"
exit 0
