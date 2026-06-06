#!/usr/bin/env bash
# Offline checks for CI signing script expectations (no secrets required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBX_SRC="${ROOT}/ios/Runner.xcodeproj/project.pbxproj"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp "$PBX_SRC" "$TMP/project.pbxproj"

perl -0777 -i -pe '
  s{(buildSettings = \{)((?:(?!\t\t\t\};)[\s\S])*?CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;(?:(?!\t\t\t\};)[\s\S])*?)(\t\t\t\};)}{
    my ($open, $body, $close) = ($1, $2, $3);
    $body =~ s/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Manual;/g;
    $body =~ s/(DEVELOPMENT_TEAM = [A-Z0-9]+;)/$1\n\t\t\t\tPROVISIONING_PROFILE = deadbeef-dead-beef-dead-beefdeadbeef;\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "iOS Team Provisioning Profile: com.amritdash.moneymatters";/;
    "$open$body$close";
  }gse
' "$TMP/project.pbxproj"

export TEAM_ID=TESTTEAM123
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
' "$TMP/project.pbxproj"

runner_blocks="$(perl -0777 -ne 'while (/(buildSettings = \{)(?:(?!\t\t\t\};)[\s\S])*?CODE_SIGN_ENTITLEMENTS = Runner\/Runner\.entitlements;(?:(?!\t\t\t\};)[\s\S])*?(\t\t\t\};)/g) { print "$&\n" }' "$TMP/project.pbxproj")"

if echo "$runner_blocks" | grep -q 'CODE_SIGN_STYLE = Manual;'; then
  echo "::error::Self-test: Runner still has Manual CODE_SIGN_STYLE"
  exit 1
fi
if echo "$runner_blocks" | grep -q 'PROVISIONING_PROFILE = '; then
  echo "::error::Self-test: PROVISIONING_PROFILE should be cleared for automatic signing"
  exit 1
fi
if ! echo "$runner_blocks" | grep -q 'DEVELOPMENT_TEAM = TESTTEAM123;'; then
  echo "::error::Self-test: DEVELOPMENT_TEAM not updated in Runner blocks"
  exit 1
fi

if ! grep -q '<string>automatic</string>' "${ROOT}/scripts/prepare_export_options_ci.sh"; then
  echo "::error::prepare_export_options_ci.sh must emit signingStyle automatic"
  exit 1
fi
if ! grep -q 'CODE_SIGN_STYLE = Automatic' "${ROOT}/scripts/configure_ci_signing.sh"; then
  echo "::error::configure_ci_signing.sh must set Automatic signing"
  exit 1
fi

echo "ci_signing_selftest passed."
