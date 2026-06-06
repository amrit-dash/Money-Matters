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

resolve_export_code_sign_identity() {
  local from_keychain=""
  if [[ -f "$KEYCHAIN_PATH" ]]; then
    from_keychain="$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" 2>/dev/null \
      | sed -n 's/^[[:space:]]*[0-9]*) \([A-F0-9]\{40\}\) "\(.*\)"$/\2/p' | head -1 || true)"
  fi
  if [[ -z "$from_keychain" ]]; then
    from_keychain="$(security find-identity -v -p codesigning 2>/dev/null \
      | sed -n 's/^[[:space:]]*[0-9]*) \([A-F0-9]\{40\}\) "\(.*\)"$/\2/p' | grep 'Apple Development' | head -1 || true)"
  fi
  if [[ -n "${CI_EXPORT_CODE_SIGN_IDENTITY:-}" ]]; then
    printf '%s' "$CI_EXPORT_CODE_SIGN_IDENTITY"
  elif [[ -n "$from_keychain" ]]; then
    printf '%s' "$from_keychain"
  else
    /usr/libexec/PlistBuddy -c 'Print :signingCertificate' "$EXPORT_PLIST" 2>/dev/null || printf '%s' 'Apple Development'
  fi
}

assert_ci_keychain() {
  if [[ ! -f "$KEYCHAIN_PATH" ]]; then
    echo "::warning::CI keychain not found at ${KEYCHAIN_PATH}; export may fail without imported cert."
    return 0
  fi
  if [[ -n "${KEYCHAIN_PASSWORD:-}" ]]; then
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" || true
  fi
  security list-keychain -d user -s "$KEYCHAIN_PATH" login.keychain-db
  echo "Using CI keychain search list: ${KEYCHAIN_PATH}, login.keychain-db"
  security find-identity -v -p codesigning | head -5 || true
}

package_signed_archive_ipa() {
  local app="${ARCHIVE_PATH}/Products/Applications/Runner.app"
  local ipa_name="${CI_IPA_NAME:-MoneyMatters.ipa}"
  if [[ ! -d "$app" ]]; then
    echo "::error::Missing ${app} in archive."
    return 1
  fi
  if ! codesign --verify --deep --strict "$app" 2>/dev/null; then
    echo "::error::Archive app is not signed; cannot package IPA without exportArchive."
    return 1
  fi
  echo "==> Packaging signed archive as ${ipa_name} (exportArchive bypass for Apple Development / Personal Team)"
  rm -rf "${EXPORT_PATH}/Payload"
  mkdir -p "${EXPORT_PATH}/Payload"
  cp -a "$app" "${EXPORT_PATH}/Payload/"
  ( cd "$EXPORT_PATH" && zip -qr "$ipa_name" Payload )
  rm -rf "${EXPORT_PATH}/Payload"
}

run_export_archive() {
  local code_sign_identity="$1"
  local team_id="$2"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    CODE_SIGN_IDENTITY="$code_sign_identity" \
    DEVELOPMENT_TEAM="$team_id"
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
CODE_SIGN_IDENTITY="$(resolve_export_code_sign_identity)"

echo "==> ExportOptions.ci.plist (method=${EXPORT_METHOD:-unknown}, team=${EXPORT_TEAM_ID:-unknown}, signingCertificate=${EXPORT_CERT:-unknown})"
echo "==> xcodebuild -exportArchive (CODE_SIGN_IDENTITY=${CODE_SIGN_IDENTITY})"

set +e
run_export_archive "$CODE_SIGN_IDENTITY" "$EXPORT_TEAM_ID"
EXPORT_RC=$?
set -e

if [[ "$EXPORT_RC" -ne 0 ]]; then
  if [[ "$ARCHIVE_MODE" == "automatic" ]]; then
    echo "::warning::exportArchive failed (exit ${EXPORT_RC}); using signed-archive IPA packaging fallback."
    package_signed_archive_ipa
  else
    echo "::error::exportArchive failed and archive mode is ${ARCHIVE_MODE} (no signed-app fallback)."
    exit "$EXPORT_RC"
  fi
fi

echo "==> IPA export complete"
ls -la "$EXPORT_PATH"/*.ipa
