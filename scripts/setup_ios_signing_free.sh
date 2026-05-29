#!/usr/bin/env bash
# Free Personal Team: automate CLI setup; Xcode GUI only where Apple requires it.
#
# Usage:
#   ./scripts/setup_ios_signing_free.sh           # clean keychain + prep + open Xcode project
#   ./scripts/setup_ios_signing_free.sh --check   # run ios_signing_doctor only
#   ./scripts/setup_ios_signing_free.sh --export  # export .p12 + copy profile (after Xcode steps)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
TEAM_ID="F4TFHKUQDA"
BUNDLE_ID="com.amritdash.moneymatters"
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
DESKTOP_P12="${HOME}/Desktop/MoneyMatters-Dev.p12"
DESKTOP_PROFILE="${HOME}/Desktop/MoneyMatters.mobileprovision"

MODE="${1:-}"

log() { echo "==> $*"; }

clean_apple_development_keychain() {
  log "Removing Apple Development certificates from login keychain"
  local hash
  while security find-certificate -c "Apple Development" -a -Z ~/Library/Keychains/login.keychain-db 2>/dev/null | grep -q "SHA-1 hash"; do
    hash="$(security find-certificate -c "Apple Development" -a -Z ~/Library/Keychains/login.keychain-db 2>/dev/null | grep "SHA-1 hash" | head -1 | awk '{print $3}')"
    [[ -n "$hash" ]] || break
    security delete-certificate -Z "$hash" ~/Library/Keychains/login.keychain-db 2>/dev/null || break
  done
  if security find-certificate -c "Apple Development" -a ~/Library/Keychains/login.keychain-db 2>/dev/null | grep -q "labl"; then
    echo "WARNING: Some Apple Development certs remain — delete in Keychain Access if needed."
  else
    echo "    Apple Development certs removed."
  fi
}

ensure_xcode_cli() {
  if [[ "$(xcode-select -p 2>/dev/null)" != "/Applications/Xcode.app/Contents/Developer" ]]; then
    log "Pointing xcode-select at Xcode.app (needs sudo)"
    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  fi
  xcodebuild -version | head -1
}

flutter_prep() {
  log "flutter pub get"
  cd "$ROOT"
  if command -v flutter >/dev/null 2>&1; then
    flutter pub get
  else
    echo "WARNING: flutter not on PATH — skip or install Flutter SDK."
  fi
}

check_ios_platform_cli() {
  if xcodebuild -showdestinations -workspace "$ROOT/ios/Runner.xcworkspace" -scheme Runner 2>&1 | grep -q "iOS 26.5 is not installed"; then
    echo ""
    echo "NOTE: Command-line builds need the iOS *platform* in Xcode Components."
    echo "      That is NOT the iOS Simulator runtime (~10 GB)."
    echo "      Xcode GUI signing (Signing & Capabilities) often still works without it."
    echo "      To install later (optional for CLI builds only):"
    echo "        xcodebuild -downloadPlatform iOS"
    echo ""
  fi
}

print_manual_steps() {
  cat <<EOF

==============================================
 MANUAL STEPS (Xcode only — ~2 minutes)
==============================================

You do NOT need developer.apple.com (paid portal).

A) Create certificate WITH private key
   1. Xcode → Settings → Accounts → amrit.dash60@gmail.com
   2. Manage Certificates… → + → Apple Development → Done
   (No − button needed; ignore grey "Not in Keychain" rows.)

B) In the project window that just opened (Runner):
   1. Left: blue Runner → TARGETS → Runner
   2. Signing & Capabilities
   3. Automatically manage signing: ON
   4. Team: Amrit Dash (Personal Team)
   5. Wait for green signing status

C) Back to Settings → Accounts → Download Manual Profiles

Then run:
   ./scripts/setup_ios_signing_free.sh --check

When both checks pass:
   ./scripts/setup_ios_signing_free.sh --export

==============================================
EOF
}

export_signing_assets() {
  local id_count
  id_count="$(security find-identity -v -p codesigning 2>/dev/null | grep -c "Apple Development" || true)"
  if [[ "$id_count" -lt 1 ]]; then
    echo "ERROR: No Apple Development identity. Complete manual steps A–C first."
    exit 1
  fi

  mkdir -p "$PROFILE_DIR"
  local profile=""
  shopt -s nullglob
  for f in "$PROFILE_DIR"/*.mobileprovision; do
    local app_id
    app_id="$(security cms -D -i "$f" 2>/dev/null | plutil -extract Entitlements:application-identifier raw - 2>/dev/null || true)"
    if [[ "$app_id" == *"$BUNDLE_ID" ]]; then
      profile="$f"
      break
    fi
  done
  if [[ -z "$profile" ]]; then
    profile="$(ls "$PROFILE_DIR"/*.mobileprovision 2>/dev/null | head -1 || true)"
  fi
  if [[ -z "$profile" ]]; then
    echo "ERROR: No .mobileprovision found. Complete manual step C (Download Manual Profiles)."
    exit 1
  fi

  echo ""
  read -r -s -p "Password for exported .p12 (you will use this as GitHub secret P12_PASSWORD): " P12_PW
  echo ""
  log "Exporting signing identity to ${DESKTOP_P12}"
  security export -f pkcs12 -k ~/Library/Keychains/login.keychain-db -t identities -P "$P12_PW" -o "$DESKTOP_P12" 2>/dev/null || {
    echo "Export failed. In Keychain Access, export Apple Development manually to ${DESKTOP_P12}"
    exit 1
  }

  cp "$profile" "$DESKTOP_PROFILE"
  log "Copied profile to ${DESKTOP_PROFILE}"

  if command -v gh >/dev/null 2>&1; then
    read -r -p "Upload to GitHub secrets now? [y/N] " ans
    case "$ans" in
      [yY]|[yY][eE][sS])
        "$ROOT/scripts/upload_signing_to_github.sh" "$DESKTOP_P12" "$DESKTOP_PROFILE"
        ;;
      *)
        echo "Later: ./scripts/upload_signing_to_github.sh \"$DESKTOP_P12\" \"$DESKTOP_PROFILE\""
        ;;
    esac
  fi
}

case "$MODE" in
  --check)
    exec "$ROOT/scripts/ios_signing_doctor.sh"
    ;;
  --export)
    export_signing_assets
    exit 0
    ;;
  --clean-only)
    clean_apple_development_keychain
    exit 0
    ;;
  "")
    ;;
  *)
    echo "Usage: $0 | $0 --check | $0 --export | $0 --clean-only"
    exit 1
    ;;
esac

log "Money Matters — free-account signing setup (CLI)"
ensure_xcode_cli
clean_apple_development_keychain
flutter_prep
check_ios_platform_cli
mkdir -p "$PROFILE_DIR"

log "Opening Runner.xcworkspace in Xcode"
open "$ROOT/ios/Runner.xcworkspace"

print_manual_steps

"$ROOT/scripts/ios_signing_doctor.sh" || true
