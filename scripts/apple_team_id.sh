#!/usr/bin/env bash
# Print Apple Team ID(s) from provisioning profiles or Xcode build settings.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "ERROR: Xcode not found at $DEVELOPER_DIR"
  echo "Install Xcode or set DEVELOPER_DIR."
  exit 1
fi

echo "==> Xcode: $($DEVELOPER_DIR/usr/bin/xcodebuild -version | head -1)"
echo ""

FOUND=0
XCODE_PREFS="$HOME/Library/Preferences/com.apple.dt.Xcode.plist"
if [[ -f "$XCODE_PREFS" ]]; then
  TID="$(plutil -p "$XCODE_PREFS" 2>/dev/null | grep '"teamID"' | head -1 | sed 's/.*"\([A-Z0-9]\{10\}\)".*/\1/')"
  TNAME="$(plutil -p "$XCODE_PREFS" 2>/dev/null | grep '"teamName"' | head -1 | sed 's/.*=> "\(.*\)"/\1/')"
  if [[ -n "$TID" ]]; then
    echo "==> Team ID from Xcode account cache:"
    echo "    ${TID}  —  ${TNAME:-Personal Team}"
    FOUND=1
    echo ""
  fi
fi
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
if [[ -d "$PROFILE_DIR" ]]; then
  echo "==> Team ID(s) from provisioning profiles:"
  shopt -s nullglob
  for profile in "$PROFILE_DIR"/*.mobileprovision; do
    TEAM="$(security cms -D -i "$profile" 2>/dev/null | plutil -extract TeamIdentifier.0 raw - 2>/dev/null || true)"
    NAME="$(security cms -D -i "$profile" 2>/dev/null | plutil -extract Name raw - 2>/dev/null || true)"
    APP_ID="$(security cms -D -i "$profile" 2>/dev/null | plutil -extract Entitlements:application-identifier raw - 2>/dev/null || true)"
    if [[ -n "$TEAM" ]]; then
      echo "    ${TEAM}  —  ${NAME:-profile}  (${APP_ID:-bundle unknown})"
      FOUND=1
    fi
  done
  echo ""
fi

if [[ -f "$ROOT/ios/Runner.xcodeproj/project.pbxproj" ]]; then
  TEAM_BUILD="$(cd "$ROOT/ios" && xcodebuild -showBuildSettings -project Runner.xcodeproj -scheme Runner -destination 'generic/platform=iOS' 2>/dev/null | awk -F' = ' '/DEVELOPMENT_TEAM/{print $2; exit}' || true)"
  if [[ -n "$TEAM_BUILD" && "$TEAM_BUILD" != "" ]]; then
    echo "==> DEVELOPMENT_TEAM in Xcode project: ${TEAM_BUILD}"
    FOUND=1
    echo ""
  fi
fi

if [[ "$FOUND" -eq 0 ]]; then
  echo "No Team ID found yet."
  echo ""
  echo "Do this once (no Simulator download required):"
  echo "  1. sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "  2. Open Xcode → Settings → Accounts → Apple ID → Personal Team"
  echo "  3. Copy Team ID (10 characters)"
  echo ""
  echo "Optional: open ios/Runner.xcworkspace → Runner → Signing → select Team,"
  echo "then run this script again."
  exit 1
fi

echo "Use this Team ID in:"
echo "  - Firebase App Check → App Attest"
echo "  - ios/ExportOptions.plist (or gh secret APPLE_TEAM_ID)"
echo "  - gh secret set APPLE_TEAM_ID --repo amrit-dash/Money-Matters"
