#!/usr/bin/env bash
# Diagnose iOS signing and print the shortest fix path.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
TEAM_ID="F4TFHKUQDA"
BUNDLE_ID="com.amritdash.moneymatters"
PROFILE_DIRS=(
  "$HOME/Library/MobileDevice/Provisioning Profiles"
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
)

echo "=============================================="
echo " Money Matters — iOS signing check"
echo "=============================================="
echo ""

# 1. Xcode path
if [[ "$(xcode-select -p 2>/dev/null)" != "/Applications/Xcode.app/Contents/Developer" ]]; then
  echo "⚠️  Xcode CLI not selected. Run:"
  echo "    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo ""
fi

# 2. Valid signing identity (cert + private key)
IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" || true)"
if [[ -z "$IDENTITIES" ]]; then
  echo "❌ PROBLEM: No usable Apple Development identity (cert + private key)."
  echo ""
  echo "   You may see a cert in Keychain, but without a private key GitHub"
  echo "   cannot sign and 'Download Manual Profiles' installs nothing useful."
  echo ""
  echo "   Xcode '+' often creates a cert WITHOUT a local private key (no − button"
  echo "   to delete until you revoke on the website)."
  echo ""
  echo "   FREE Personal Team (no paid program):"
  echo "   → docs/SETUP-SIGNING-FREE-ACCOUNT.md  (Xcode only — NOT the website)"
  echo ""
  echo "   Paid \$99/year program only:"
  echo "   → docs/SETUP-CERT-KEYCHAIN.md"
  echo ""
  echo "   Quick verify in Keychain Access → login → Keys — you should see a"
  echo "   private key under My Certificates → Apple Development (expand ▶)."
  echo ""
  echo "   Then run this script again:"
  echo "     ./scripts/ios_signing_doctor.sh"
  echo ""
  HAS_IDENTITY=0
else
  echo "✅ Signing identity found:"
  echo "$IDENTITIES" | sed 's/^/   /'
  echo ""
  HAS_IDENTITY=1
fi

# 3. Provisioning profiles
MATCHING=()
shopt -s nullglob
for PROFILE_DIR in "${PROFILE_DIRS[@]}"; do
  mkdir -p "$PROFILE_DIR"
  for f in "$PROFILE_DIR"/*.mobileprovision; do
    APP_ID="$(security cms -D -i "$f" 2>/dev/null | grep -A1 application-identifier | tail -1 | sed 's/.*<string>//;s/<\/string>//' | tr -d '[:space:]' || true)"
    if [[ "$APP_ID" == *"$BUNDLE_ID" ]]; then
      MATCHING+=("$f")
    fi
  done
done

if [[ ${#MATCHING[@]} -gt 0 ]]; then
  echo "✅ Provisioning profile for ${BUNDLE_ID}:"
  for f in "${MATCHING[@]}"; do
    NAME="$(security cms -D -i "$f" 2>/dev/null | plutil -extract Name raw - 2>/dev/null || true)"
    echo "   ${NAME:-profile}"
    echo "   $f"
  done
  echo ""
  HAS_PROFILE=1
else
  echo "❌ PROBLEM: No provisioning profile for ${BUNDLE_ID}."
  echo ""
  echo "   'Download Manual Profiles' only refreshes profiles that ALREADY"
  echo "   exist on Apple's servers. Yours were never created for this app."
  echo ""
  if [[ "$HAS_IDENTITY" -eq 1 ]]; then
    echo "   FIX: docs/SETUP-SIGNING-FREE-ACCOUNT.md (Step 3 — open Runner.xcworkspace)"
  else
    echo "   FIX: Fix the certificate first (above), then"
    echo "        docs/SETUP-SIGNING-FREE-ACCOUNT.md Step 3 (Xcode automatic signing)"
  fi
  echo ""
  HAS_PROFILE=0
fi

# 4. Ready for GitHub?
echo "----------------------------------------------"
if [[ "$HAS_IDENTITY" -eq 1 && "$HAS_PROFILE" -eq 1 ]]; then
  echo "✅ Ready to export and upload GitHub secrets."
  echo ""
  echo "   1. Keychain Access → My Certificates → Apple Development"
  echo "      → expand ▶ (must show private key) → Export .p12"
  echo "   2. Copy profile to Desktop:"
  echo "      cp \"${MATCHING[0]}\" ~/Desktop/MoneyMatters.mobileprovision"
  echo "   3. Run:"
  echo "      ./scripts/upload_signing_to_github.sh ~/Desktop/MoneyMatters-Dev.p12 ~/Desktop/MoneyMatters.mobileprovision"
else
  echo "⏳ Not ready for GitHub IPA yet — fix the ❌ items above first."
fi
echo "=============================================="
