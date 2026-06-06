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

# Re-assert CI keychain for xcodebuild/codesign (same job as import_ci_signing_keychain.sh).
KEYCHAIN_PATH="${KEYCHAIN_PATH:-${RUNNER_TEMP:-}/app-signing.keychain-db}"
if [[ -f "$KEYCHAIN_PATH" ]]; then
  if [[ -n "${KEYCHAIN_PASSWORD:-}" ]]; then
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" || true
  fi
  security list-keychain -d user -s "$KEYCHAIN_PATH"
  echo "Using CI keychain: ${KEYCHAIN_PATH}"
  security find-identity -v -p codesigning | head -3 || true
fi

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

echo "==> xcodebuild -exportArchive (manual ExportOptions.ci.plist; no Xcode Apple account)"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_PLIST"

echo "==> IPA export complete"
ls -la "$EXPORT_PATH"/*.ipa
