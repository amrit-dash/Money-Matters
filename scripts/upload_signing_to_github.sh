#!/usr/bin/env bash
# Upload signing files to GitHub Actions secrets (interactive passwords).
set -euo pipefail

REPO="${3:-amrit-dash/Money-Matters}"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <certificate.p12> <profile.mobileprovision> [owner/repo]"
  echo ""
  echo "Example:"
  echo "  $0 ~/Desktop/MoneyMatters-Dev.p12 ~/Desktop/MoneyMatters.mobileprovision"
  exit 1
fi

P12="$1"
PROFILE="$2"

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: Install GitHub CLI: brew install gh && gh auth login"
  exit 1
fi

for f in "$P12" "$PROFILE"; do
  [[ -f "$f" ]] || { echo "ERROR: File not found: $f"; exit 1; }
done

echo "==> Uploading to ${REPO}"
base64 -i "$P12" | gh secret set BUILD_CERTIFICATE_BASE64 --repo "${REPO}"
base64 -i "$PROFILE" | gh secret set BUILD_PROVISION_PROFILE_BASE64 --repo "${REPO}"

validate_p12_private_key() {
  local pass="$1"
  if ! openssl pkcs12 -in "$P12" -passin "pass:${pass}" -nocerts -nodes 2>/dev/null | grep -qE 'BEGIN (RSA |EC )?PRIVATE KEY'; then
    echo "ERROR: $P12 does not contain a private key."
    echo "       Export from Keychain Access → My Certificates → Apple Development (must show nested private key under ▶)."
    exit 1
  fi
}

if ! gh secret list --repo "${REPO}" | grep -q '^P12_PASSWORD'; then
  echo ""
  read -r -s -p "P12 export password (for secret P12_PASSWORD): " P12_PW
  echo ""
  validate_p12_private_key "$P12_PW"
  gh secret set P12_PASSWORD --body "$P12_PW" --repo "${REPO}"
else
  echo ""
  read -r -s -p "P12 password (to validate export before upload; not stored): " P12_PW
  echo ""
  validate_p12_private_key "$P12_PW"
fi

if ! gh secret list --repo "${REPO}" | grep -q '^KEYCHAIN_PASSWORD'; then
  KC_PW="$(openssl rand -base64 24)"
  gh secret set KEYCHAIN_PASSWORD --body "$KC_PW" --repo "${REPO}"
  echo "Set KEYCHAIN_PASSWORD (random, saved to GitHub)."
fi

gh secret set APPLE_TEAM_ID --body "F4TFHKUQDA" --repo "${REPO}" 2>/dev/null || true

echo ""
echo "✅ Signing secrets uploaded."
echo "Next: GitHub → Actions → iOS IPA → Run workflow → download MoneyMatters-ipa"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/ios_signing_doctor.sh" 2>/dev/null | tail -8 || true
