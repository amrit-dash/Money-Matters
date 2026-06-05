#!/usr/bin/env bash
# Configure Xcode project for manual signing on CI (no Apple ID in Xcode).
set -euo pipefail

PROFILE="${1:?Usage: $0 path/to/profile.mobileprovision}"
PBXPROJ="${2:-ios/Runner.xcodeproj/project.pbxproj}"
EXPECTED_BUNDLE_ID="${3:-com.amritdash.moneymatters}"

PLIST_XML="$(security cms -D -i "$PROFILE")"
TEAM_ID="$(printf '%s' "$PLIST_XML" | plutil -extract TeamIdentifier.0 raw -)"
PROFILE_NAME="$(printf '%s' "$PLIST_XML" | plutil -extract Name raw -)"
APP_ID="$(printf '%s' "$PLIST_XML" | plutil -extract Entitlements.application-identifier raw -)"
BUNDLE_ID="${APP_ID#*.}"

if [[ "$BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]]; then
  echo "::error::Provisioning profile targets '${BUNDLE_ID}' but the project expects '${EXPECTED_BUNDLE_ID}'. Re-export a profile for the correct App ID and update BUILD_PROVISION_PROFILE_BASE64."
  exit 1
fi

export TEAM_ID PROFILE_NAME
perl -0777 -i -pe '
  s{(buildSettings = \{)(.*?PRODUCT_BUNDLE_IDENTIFIER = com\.amritdash\.moneymatters;.*?)(\t\t\t\};)}{
    my ($open, $body, $close) = ($1, $2, $3);
    $body =~ s/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Manual;/g;
    $body =~ s/PROVISIONING_PROFILE_SPECIFIER = "";/PROVISIONING_PROFILE_SPECIFIER = "$ENV{PROFILE_NAME}";/g;
    $body =~ s/DEVELOPMENT_TEAM = [A-Z0-9]+;/DEVELOPMENT_TEAM = $ENV{TEAM_ID};/g;
    "$open$body$close";
  }gse
' "$PBXPROJ"

echo "Configured manual signing in ${PBXPROJ}"
echo "  team=${TEAM_ID}"
echo "  profile=${PROFILE_NAME}"
echo "  bundle=${BUNDLE_ID}"
