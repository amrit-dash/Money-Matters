#!/usr/bin/env bash
# Validate imported CI signing assets before xcodebuild.
set -euo pipefail

PROFILE="${1:?Usage: $0 path/to/profile.mobileprovision}"
EXPECTED_BUNDLE_ID="${2:-com.amritdash.moneymatters}"

PLIST_XML="$(security cms -D -i "$PROFILE")"
TEAM_ID="$(printf '%s' "$PLIST_XML" | plutil -extract TeamIdentifier.0 raw -)"
PROFILE_NAME="$(printf '%s' "$PLIST_XML" | plutil -extract Name raw -)"
PROFILE_UUID="$(printf '%s' "$PLIST_XML" | plutil -extract UUID raw -)"
APP_ID="$(printf '%s' "$PLIST_XML" | plutil -extract Entitlements.application-identifier raw -)"
BUNDLE_ID="${APP_ID#*.}"
EXPIRATION="$(printf '%s' "$PLIST_XML" | plutil -extract ExpirationDate raw - 2>/dev/null || true)"

echo "Provisioning profile:"
echo "  name=${PROFILE_NAME}"
echo "  uuid=${PROFILE_UUID}"
echo "  team=${TEAM_ID}"
echo "  bundle=${BUNDLE_ID}"
echo "  expires=${EXPIRATION:-unknown}"

if [[ "$BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]]; then
  echo "::error::Profile bundle id '${BUNDLE_ID}' does not match '${EXPECTED_BUNDLE_ID}'."
  exit 1
fi

if [[ -n "$EXPIRATION" ]] && [[ "$EXPIRATION" < "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" ]]; then
  echo "::error::Provisioning profile expired at ${EXPIRATION}. Re-export from Xcode and update BUILD_PROVISION_PROFILE_BASE64."
  exit 1
fi

PROFILE_DIRS=(
  "$HOME/Library/MobileDevice/Provisioning Profiles"
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
)
FOUND=0
for dir in "${PROFILE_DIRS[@]}"; do
  if [[ -f "$dir/${PROFILE_UUID}.mobileprovision" ]]; then
    echo "Profile installed: $dir/${PROFILE_UUID}.mobileprovision"
    FOUND=1
  fi
done
if [[ "$FOUND" -eq 0 ]]; then
  echo "::error::Profile ${PROFILE_UUID} is not installed in expected directories."
  exit 1
fi

IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" || true)"
if [[ -z "$IDENTITIES" ]]; then
  echo "::error::No Apple Development signing identity in keychain. Check BUILD_CERTIFICATE_BASE64 and P12_PASSWORD."
  exit 1
fi
echo "Keychain identities:"
echo "$IDENTITIES"

KEYCHAIN_SHA="$(printf '%s\n' "$IDENTITIES" | sed -n 's/.*) \([A-F0-9]\{40\}\) .*/\1/p' | head -1)"
PROFILE_CERT_DER="$(printf '%s' "$PLIST_XML" | plutil -extract DeveloperCertificates.0 raw -)"
PROFILE_SHA="$(printf '%s' "$PROFILE_CERT_DER" | openssl x509 -inform DER -fingerprint -sha1 -noout 2>/dev/null | tr -d ':' | cut -d= -f2 || true)"

if [[ -n "$KEYCHAIN_SHA" && -n "$PROFILE_SHA" && "$KEYCHAIN_SHA" != "$PROFILE_SHA" ]]; then
  echo "::error::Certificate in .p12 (${KEYCHAIN_SHA}) does not match provisioning profile (${PROFILE_SHA})."
  echo "::error::Re-export a matching .p12 and .mobileprovision from the same Mac/Xcode session, then run ./scripts/upload_signing_to_github.sh"
  exit 1
fi

echo "CI signing verification passed."
