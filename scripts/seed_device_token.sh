#!/usr/bin/env bash
# Register the ingest Bearer token in Firestore (one-time per device).
# Use when Connect SMS Test POST returns 401 until a new app build registers tokens.
#
# Usage:
#   ./scripts/seed_device_token.sh <firebase_uid> <device_id> <raw_bearer_token>
#
# Example (values from Money Matters → Connect SMS):
#   ./scripts/seed_device_token.sh "$UID" "3e2256f8-1625-4b81-958b-f470db1bd158" "5b6c7d8e..."
#
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <firebase_uid> <device_id> <raw_bearer_token>"
  exit 1
fi

UID="$1"
DEVICE_ID="$2"
TOKEN="$3"
HASH="$(printf '%s' "$TOKEN" | shasum -a 256 | awk '{print $1}')"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}/firebase"

echo "Writing users/${UID}/device_tokens/${DEVICE_ID}"
echo "tokenHash=${HASH}"

firebase firestore:documents:set \
  "users/${UID}/device_tokens/${DEVICE_ID}" \
  "{\"tokenHash\":\"${HASH}\",\"label\":\"iPhone\",\"createdAt\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
  --project money-matters-amrit

echo "Done. Retry Test POST in the app."
