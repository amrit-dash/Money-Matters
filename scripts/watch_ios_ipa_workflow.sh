#!/usr/bin/env bash
# Watch the latest (or in-progress) iOS IPA GitHub Actions run until it finishes.
set -euo pipefail

REPO="${1:-amrit-dash/Money-Matters}"
RUN_ID="${2:-}"

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: Install GitHub CLI: brew install gh && gh auth login"
  exit 1
fi

if [[ -z "$RUN_ID" ]]; then
  RUN_ID="$(gh run list --repo "$REPO" --workflow=ios-ipa.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
fi

echo "==> Watching run $RUN_ID on $REPO"
gh run watch "$RUN_ID" --repo "$REPO" --exit-status
echo ""
gh run view "$RUN_ID" --repo "$REPO"
