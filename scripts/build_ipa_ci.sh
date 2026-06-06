#!/usr/bin/env bash
# CI-only: signed archive + IPA export via Flutter (single xcodebuild pipeline).
# Requires Import code signing step (keychain, profile, ExportOptions.ci.plist, automatic Runner signing).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

EXPORT_PLIST="${ROOT}/ios/ExportOptions.ci.plist"
EXPORT_PATH="${ROOT}/build/ios/ipa"

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

mkdir -p "$EXPORT_PATH"

export FLUTTER_XCODE_CODE_SIGN_STYLE=Automatic
echo "==> flutter build ipa --release --export-options-plist=${EXPORT_PLIST}"
flutter build ipa --release --export-options-plist="$EXPORT_PLIST"

echo "==> IPA export complete"
ls -la "$EXPORT_PATH"/*.ipa
