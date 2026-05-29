#!/usr/bin/env bash
# Print base64 payloads and gh secret commands for iOS code signing.
#
# Usage:
#   ./scripts/encode_signing_secrets.sh path/to/cert.p12 path/to/profile.mobileprovision
#   ./scripts/encode_signing_secrets.sh path/to/cert.p12 path/to/profile.mobileprovision amrit-dash/Money-Matters
#
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <certificate.p12> <profile.mobileprovision> [owner/repo]"
  exit 1
fi

P12="$1"
PROFILE="$2"
REPO="${3:-amrit-dash/Money-Matters}"

if [[ ! -f "$P12" ]]; then
  echo "ERROR: P12 not found: $P12"
  exit 1
fi
if [[ ! -f "$PROFILE" ]]; then
  echo "ERROR: Provisioning profile not found: $PROFILE"
  exit 1
fi

TEAM_ID=""
PROFILE_NAME=""
if command -v security >/dev/null 2>&1; then
  PLIST_XML="$(security cms -D -i "$PROFILE" 2>/dev/null || true)"
  if [[ -n "$PLIST_XML" ]]; then
    TEAM_ID="$(printf '%s' "$PLIST_XML" | plutil -extract TeamIdentifier.0 raw - 2>/dev/null || true)"
    PROFILE_NAME="$(printf '%s' "$PLIST_XML" | plutil -extract Name raw - 2>/dev/null || true)"
  fi
fi

echo "==> Extracted from provisioning profile"
echo "    Team ID:        ${TEAM_ID:-unknown}"
echo "    Profile name:   ${PROFILE_NAME:-unknown}"
echo ""
echo "==> Update ios/ExportOptions.plist"
echo "    teamID → ${TEAM_ID:-YOUR_TEAM_ID}"
if [[ -n "$PROFILE_NAME" ]]; then
  echo "    For CI manual export, profile name: ${PROFILE_NAME}"
fi
echo ""

CERT_B64="$(base64 -i "$P12" | tr -d '\n')"
PROFILE_B64="$(base64 -i "$PROFILE" | tr -d '\n')"

echo "==> GitHub secrets (repo: ${REPO})"
echo ""
echo "# Paste P12 password when prompted:"
echo "gh secret set P12_PASSWORD --repo ${REPO}"
echo ""
echo "# Random string only used on the Actions runner keychain:"
echo "gh secret set KEYCHAIN_PASSWORD --repo ${REPO}"
echo ""
if [[ -n "$TEAM_ID" ]]; then
  echo "gh secret set APPLE_TEAM_ID --body '${TEAM_ID}' --repo ${REPO}"
  echo ""
fi

if command -v gh >/dev/null 2>&1; then
  read -r -p "Set BUILD_CERTIFICATE_BASE64 now? [y/N] " ans
  case "$ans" in
    [yY]|[yY][eE][sS])
    printf '%s' "$CERT_B64" | gh secret set BUILD_CERTIFICATE_BASE64 --repo "${REPO}"
    printf '%s' "$PROFILE_B64" | gh secret set BUILD_PROVISION_PROFILE_BASE64 --repo "${REPO}"
    echo "Set BUILD_CERTIFICATE_BASE64 and BUILD_PROVISION_PROFILE_BASE64."
    ;;
  *)
    echo "CERT base64 length: ${#CERT_B64} chars (use: gh secret set BUILD_CERTIFICATE_BASE64 --repo ${REPO})"
    echo "PROFILE base64 length: ${#PROFILE_B64} chars"
    ;;
  esac
else
  echo "Install gh to push secrets automatically: brew install gh && gh auth login"
  echo "Or paste in GitHub → Settings → Secrets → Actions:"
  echo "  BUILD_CERTIFICATE_BASE64"
  echo "  BUILD_PROVISION_PROFILE_BASE64"
fi
