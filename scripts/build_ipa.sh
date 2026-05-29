#!/usr/bin/env bash
# Build a release IPA for Money Matters (iOS).
#
# Prerequisites (on your Mac):
#   - Full Xcode 15+ installed (not Command Line Tools only)
#   - CocoaPods: gem install cocoapods  OR  brew install cocoapods
#   - Flutter SDK 3.11+ (flutter doctor — fix iOS items)
#   - Apple Developer account; Team selected in Xcode for Runner target
#   - GoogleService-Info.plist in ios/Runner/
#   - flutterfire configure completed (lib/core/config/firebase_options.dart)
#
# Signing:
#   1. open ios/Runner.xcworkspace
#   2. Runner target → Signing & Capabilities → select your Team
#   3. Edit ios/ExportOptions.plist → replace YOUR_TEAM_ID
#
# Usage:
#   ./scripts/build_ipa.sh              # flutter build ipa (default)
#   ./scripts/build_ipa.sh ios-only     # flutter build ios --release (no IPA export)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODE="${1:-ipa}"

echo "==> Money Matters iOS build (mode: ${MODE})"
echo "    Root: ${ROOT}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter not found on PATH. Install Flutter and run flutter doctor."
  exit 1
fi

if [[ ! -f ios/Runner/GoogleService-Info.plist ]]; then
  echo "WARNING: ios/Runner/GoogleService-Info.plist missing."
  echo "         Download from Firebase Console before release builds."
fi

if grep -q 'isConfigured = false' lib/core/config/firebase_options.dart 2>/dev/null; then
  echo "WARNING: firebase_options.dart is still placeholder. Run flutterfire configure."
fi

echo "==> flutter pub get"
flutter pub get

echo "==> pod install (ios/)"
if command -v pod >/dev/null 2>&1; then
  (cd ios && pod install)
else
  echo "WARNING: CocoaPods (pod) not found. Install: sudo gem install cocoapods"
  echo "         Skipping pod install — flutter build may fail."
fi

EXPORT_PLIST="${ROOT}/ios/ExportOptions.plist"

case "${MODE}" in
  ipa)
    echo "==> flutter build ipa --release"
    if [[ -f "${EXPORT_PLIST}" ]]; then
      flutter build ipa --release --export-options-plist="${EXPORT_PLIST}"
    else
      echo "NOTE: ${EXPORT_PLIST} not found; using Xcode-managed export options."
      flutter build ipa --release
    fi
    echo ""
    echo "Done. IPA (if export succeeded):"
    echo "  ${ROOT}/build/ios/ipa/*.ipa"
    ;;
  ios-only)
    echo "==> flutter build ios --release"
    flutter build ios --release
    echo ""
    echo "Done. App bundle:"
    echo "  ${ROOT}/build/ios/iphoneos/Runner.app"
    echo ""
    echo "To install: open ios/Runner.xcworkspace → Product → Run on device,"
    echo "or Archive in Xcode (Product → Archive) and export with your Team."
    ;;
  *)
    echo "Usage: $0 [ipa|ios-only]"
    exit 1
    ;;
esac
