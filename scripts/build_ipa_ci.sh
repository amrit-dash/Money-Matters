#!/usr/bin/env bash
# CI-only: archive (automatic or unsigned) + manual IPA export for headless runners (no Apple ID in Xcode).
# Requires Import code signing step (keychain, profile, ExportOptions.ci.plist).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

EXPORT_PLIST="${ROOT}/ios/ExportOptions.ci.plist"
ARCHIVE_PATH="${ROOT}/build/ios/archive/Runner.xcarchive"
EXPORT_PATH="${ROOT}/build/ios/ipa"
# automatic = Personal Team archive via project signing + keychain; unsigned = compile without codesign then unsigned archive (export re-signs).
ARCHIVE_MODE="${CI_ARCHIVE_MODE:-automatic}"

if [[ ! -f "$EXPORT_PLIST" ]]; then
  echo "::error::Missing ${EXPORT_PLIST}. Run prepare_export_options_ci.sh first."
  exit 1
fi

KEYCHAIN_PATH="${KEYCHAIN_PATH:-${RUNNER_TEMP:-}/app-signing.keychain-db}"

assert_ci_keychain() {
  if [[ ! -f "$KEYCHAIN_PATH" ]]; then
    echo "::warning::CI keychain not found at ${KEYCHAIN_PATH}; export may fail without imported cert."
    return 0
  fi
  if [[ -n "${KEYCHAIN_PASSWORD:-}" ]]; then
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" || true
  fi
  # Headless export must search the imported keychain first; include login for any system trust roots.
  security list-keychain -d user -s "$KEYCHAIN_PATH" login.keychain-db
  echo "Using CI keychain search list: ${KEYCHAIN_PATH}, login.keychain-db"
  security find-identity -v -p codesigning "$KEYCHAIN_PATH" | head -5 || true
}

assert_ci_keychain

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

case "$ARCHIVE_MODE" in
  automatic)
    export FLUTTER_XCODE_CODE_SIGN_STYLE=Automatic
    echo "==> flutter build ios --release (automatic signing)"
    flutter build ios --release
    echo "==> xcodebuild archive (automatic signing from project + keychain)"
    xcodebuild archive \
      -workspace ios/Runner.xcworkspace \
      -scheme Runner \
      -configuration Release \
      -archivePath "$ARCHIVE_PATH" \
      -destination 'generic/platform=iOS'
    ;;
  unsigned)
    echo "==> flutter build ios --release --no-codesign"
    flutter build ios --release --no-codesign
    echo "==> xcodebuild archive (unsigned; export will sign with ExportOptions.ci.plist)"
    xcodebuild archive \
      -workspace ios/Runner.xcworkspace \
      -scheme Runner \
      -configuration Release \
      -archivePath "$ARCHIVE_PATH" \
      -destination 'generic/platform=iOS' \
      CODE_SIGN_IDENTITY="" \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGNING_ALLOWED=NO
    ;;
  *)
    echo "::error::Invalid CI_ARCHIVE_MODE=${ARCHIVE_MODE} (use automatic or unsigned)"
    exit 1
    ;;
esac

assert_ci_keychain

EXPORT_TEAM_ID="$(/usr/libexec/PlistBuddy -c 'Print :teamID' "$EXPORT_PLIST" 2>/dev/null || true)"
EXPORT_CERT="$(/usr/libexec/PlistBuddy -c 'Print :signingCertificate' "$EXPORT_PLIST" 2>/dev/null || true)"
EXPORT_METHOD="$(/usr/libexec/PlistBuddy -c 'Print :method' "$EXPORT_PLIST" 2>/dev/null || true)"
CODE_SIGN_IDENTITY="${CI_EXPORT_CODE_SIGN_IDENTITY:-${EXPORT_CERT:-Apple Development}}"

echo "==> ExportOptions.ci.plist (method=${EXPORT_METHOD:-unknown}, team=${EXPORT_TEAM_ID:-unknown}, signingCertificate=${EXPORT_CERT:-unknown})"
echo "==> xcodebuild -exportArchive (manual ExportOptions.ci.plist; CODE_SIGN_IDENTITY=${CODE_SIGN_IDENTITY})"

# Xcode 16 exportArchive still searches for legacy certificate label "iOS Development" unless
# CODE_SIGN_IDENTITY / DEVELOPMENT_TEAM are passed on the command line (Apple Development in keychain).
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
  DEVELOPMENT_TEAM="${EXPORT_TEAM_ID}"

echo "==> IPA export complete"
ls -la "$EXPORT_PATH"/*.ipa
