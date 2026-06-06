#!/usr/bin/env bash
# CI-only: archive unsigned, export signed with ios/ExportOptions.ci.plist.
# Requires Import code signing step to have run first.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

EXPORT_PLIST="${ROOT}/ios/ExportOptions.ci.plist"
ARCHIVE_PATH="${ROOT}/build/ios/archive/Runner.xcarchive"
EXPORT_PATH="${ROOT}/build/ios/ipa"

if [[ ! -f "$EXPORT_PLIST" ]]; then
  echo "::error::Missing ${EXPORT_PLIST}. Run prepare_export_options_ci.sh first."
  exit 1
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

echo "==> flutter build ios --release --no-codesign"
flutter build ios --release --no-codesign

echo "==> xcodebuild archive (unsigned)"
xcodebuild archive \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

echo "==> xcodebuild -exportArchive (manual signing)"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_PLIST"

echo "==> IPA export complete"
ls -la "$EXPORT_PATH"/*.ipa
