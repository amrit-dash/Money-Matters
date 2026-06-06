#!/usr/bin/env bash
# Configure Xcode project for automatic signing on CI (Personal Team / Xcode-managed profile).
set -euo pipefail

PROFILE="${1:?Usage: $0 path/to/profile.mobileprovision}"
PBXPROJ="${2:-ios/Runner.xcodeproj/project.pbxproj}"
EXPECTED_BUNDLE_ID="${3:-com.amritdash.moneymatters}"

PLIST_XML="$(security cms -D -i "$PROFILE")"
TEAM_ID="$(printf '%s' "$PLIST_XML" | plutil -extract TeamIdentifier.0 raw -)"
PROFILE_NAME="$(printf '%s' "$PLIST_XML" | plutil -extract Name raw -)"
PROFILE_UUID="$(printf '%s' "$PLIST_XML" | plutil -extract UUID raw -)"
APP_ID="$(printf '%s' "$PLIST_XML" | plutil -extract Entitlements.application-identifier raw -)"
BUNDLE_ID="${APP_ID#*.}"

if [[ "$BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]]; then
  echo "::error::Provisioning profile targets '${BUNDLE_ID}' but the project expects '${EXPECTED_BUNDLE_ID}'. Re-export a profile for the correct App ID and update BUILD_PROVISION_PROFILE_BASE64."
  exit 1
fi

export TEAM_ID
perl -0777 -i -pe '
  s{(buildSettings = \{)((?:(?!\t\t\t\};)[\s\S])*?CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;(?:(?!\t\t\t\};)[\s\S])*?)(\t\t\t\};)}{
    my ($open, $body, $close) = ($1, $2, $3);
    $body =~ s/CODE_SIGN_STYLE = Manual;/CODE_SIGN_STYLE = Automatic;/g;
    if ($body !~ /CODE_SIGN_STYLE =/) {
      $body =~ s/(CODE_SIGN_ENTITLEMENTS = Runner\/Runner\.entitlements;)/$1\n\t\t\t\tCODE_SIGN_STYLE = Automatic;/;
    }
    $body =~ s/\t\t\t\tPROVISIONING_PROFILE = [^;]+;\n?//g;
    $body =~ s/PROVISIONING_PROFILE_SPECIFIER = [^;]+;/PROVISIONING_PROFILE_SPECIFIER = "";/g;
    if ($body !~ /PROVISIONING_PROFILE_SPECIFIER =/) {
      $body =~ s/(DEVELOPMENT_TEAM = [A-Z0-9]+;)/$1\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "";/;
    }
    if ($body !~ /CODE_SIGN_IDENTITY =/) {
      $body =~ s/(CODE_SIGN_STYLE = Automatic;)/$1\n\t\t\t\tCODE_SIGN_IDENTITY = "Apple Development";/;
    }
    $body =~ s/DEVELOPMENT_TEAM = [A-Z0-9]+;/DEVELOPMENT_TEAM = $ENV{TEAM_ID};/g;
    "$open$body$close";
  }gse
' "$PBXPROJ"

echo "Configured automatic signing in ${PBXPROJ}"
echo "  team=${TEAM_ID}"
echo "  profile=${PROFILE_NAME} (installed in keychain dirs; Xcode-managed)"
echo "  profile_uuid=${PROFILE_UUID}"
echo "  bundle=${BUNDLE_ID}"
