#!/usr/bin/env bash
# Create CI keychain, import .p12 (cert + private key), allow codesign access.
set -euo pipefail

CERT_PATH="${1:?Usage: $0 certificate.p12 keychain-path}"
KEYCHAIN_PATH="${2:?Usage: $0 certificate.p12 keychain-path}"
P12_PASSWORD="${P12_PASSWORD:?Set P12_PASSWORD}"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:?Set KEYCHAIN_PASSWORD}"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

set +e
IMPORT_ERR=$(
  security import "$CERT_PATH" -P "$P12_PASSWORD" -A -f pkcs12 \
    -k "$KEYCHAIN_PATH" \
    -T /usr/bin/codesign -T /usr/bin/security 2>&1
)
IMPORT_RC=$?
set -e
if [ "$IMPORT_RC" -ne 0 ]; then
  echo "$IMPORT_ERR"
  echo "::error::Could not import BUILD_CERTIFICATE_BASE64 (.p12). This almost always means P12_PASSWORD does not match the password used when exporting the .p12, or the certificate secret is stale/wrong. Fix: re-export .p12 from Keychain Access (Apple Development + private key), then update BOTH secrets — gh secret set P12_PASSWORD --repo amrit-dash/Money-Matters and re-upload BUILD_CERTIFICATE_BASE64. See docs/SETUP-SIGNING-FREE-ACCOUNT.md."
  exit 1
fi

KEYCHAIN_IDENTITIES="$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" 2>/dev/null || true)"
echo "$KEYCHAIN_IDENTITIES"
if ! echo "$KEYCHAIN_IDENTITIES" | grep -qE '^[[:space:]]*[1-9][0-9]*\)'; then
  echo "::error::.p12 imported but no valid codesigning identity in the CI keychain. The file is usually missing the private key — in Keychain Access, expand Apple Development (▶) and confirm a key is nested, then export again. Do not use -t cert-only exports or certificate files without the key. See docs/SETUP-SIGNING-FREE-ACCOUNT.md."
  exit 1
fi

set +e
PART_ERR=$(security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" 2>&1)
PART_RC=$?
set -e
if [ "$PART_RC" -ne 0 ]; then
  echo "$PART_ERR"
  echo "::error::Could not set key partition list on the CI keychain (SecItemCopyMatching). Re-export a .p12 that includes the Apple Development certificate and its private key from the same Mac that created the cert."
  exit 1
fi


LOGIN_KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
if [[ -f "$LOGIN_KEYCHAIN" ]]; then
  set +e
  LOGIN_IMPORT_ERR=$(
    security import "$CERT_PATH" -P "$P12_PASSWORD" -A -f pkcs12       -k "$LOGIN_KEYCHAIN"       -T /usr/bin/codesign -T /usr/bin/security 2>&1
  )
  LOGIN_IMPORT_RC=$?
  set -e
  if [[ "$LOGIN_IMPORT_RC" -ne 0 ]] && ! echo "$LOGIN_IMPORT_ERR" | grep -qiE 'already in|SecKeychainItemImport.*duplicate'; then
    echo "$LOGIN_IMPORT_ERR"
    echo "::warning::Could not import .p12 into login keychain (exportArchive may require it)."
  else
    set +e
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$LOGIN_KEYCHAIN" 2>/dev/null
    set -e
    echo "Also imported signing cert into login keychain for IDEDistribution export."
  fi
fi

security list-keychain -d user -s "$KEYCHAIN_PATH" login.keychain-db
echo "CI keychain import succeeded."
