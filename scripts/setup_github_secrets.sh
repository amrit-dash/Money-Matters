#!/usr/bin/env bash
# Push GitHub Actions secrets for Money Matters (requires: gh auth login).
#
# Usage:
#   ./scripts/setup_github_secrets.sh
#   ./scripts/setup_github_secrets.sh amrit-dash/Money-Matters
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${1:-amrit-dash/Money-Matters}"
PLIST="${ROOT}/ios/Runner/GoogleService-Info.plist"

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: Install GitHub CLI: brew install gh && gh auth login"
  exit 1
fi

echo "==> Repository: ${REPO}"

if [[ -f "${PLIST}" ]]; then
  echo "==> Setting GOOGLE_SERVICE_INFO_PLIST_BASE64"
  base64 -i "${PLIST}" | gh secret set GOOGLE_SERVICE_INFO_PLIST_BASE64 --repo "${REPO}"
else
  echo "SKIP: ${PLIST} not found (gitignored). Download from Firebase Console first."
fi

echo ""
echo "Signing secrets (installable IPA):"
echo "  ./scripts/encode_signing_secrets.sh path/to/cert.p12 path/to/profile.mobileprovision ${REPO}"
echo ""
echo "Full steps: docs/SETUP-SIGNING.md"
