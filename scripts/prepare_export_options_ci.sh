#!/usr/bin/env bash
# Build ios/ExportOptions.ci.plist from a .mobileprovision (CI signing).
set -euo pipefail

PROFILE="${1:?Usage: $0 path/to/profile.mobileprovision}"
OUT="${2:-ios/ExportOptions.ci.plist}"

PLIST_XML="$(security cms -D -i "$PROFILE")"
TEAM_ID="$(printf '%s' "$PLIST_XML" | plutil -extract TeamIdentifier.0 raw -)"
PROFILE_NAME="$(printf '%s' "$PLIST_XML" | plutil -extract Name raw -)"
APP_ID="$(printf '%s' "$PLIST_XML" | plutil -extract Entitlements.application-identifier raw -)"
BUNDLE_ID="${APP_ID#*.}"

# CI has no Apple ID in Xcode — manual export with the imported profile + keychain cert.
# Archive may use automatic or unsigned signing; export always uses this plist.
# method=debugging (Xcode 16+; replaces deprecated "development").
# signingCertificate must be "Apple Development" — exportArchive otherwise looks for legacy "iOS Development".
cat > "$OUT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>debugging</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>signingCertificate</key>
	<string>Apple Development</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>${BUNDLE_ID}</key>
		<string>${PROFILE_NAME}</string>
	</dict>
	<key>compileBitcode</key>
	<false/>
	<key>uploadBitcode</key>
	<false/>
	<key>uploadSymbols</key>
	<true/>
	<key>destination</key>
	<string>export</string>
	<key>thinning</key>
	<string>&lt;none&gt;</string>
</dict>
</plist>
PLIST

echo "Wrote ${OUT} (team=${TEAM_ID}, profile=${PROFILE_NAME}, bundle=${BUNDLE_ID}, signing=manual, method=debugging)"
