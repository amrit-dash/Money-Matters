#!/usr/bin/env bash
# Build ios/ExportOptions.ci.plist from a .mobileprovision (CI signing).
set -euo pipefail

PROFILE="${1:?Usage: $0 path/to/profile.mobileprovision}"
OUT="${2:-ios/ExportOptions.ci.plist}"

PLIST_XML="$(security cms -D -i "$PROFILE")"
TEAM_ID="$(printf '%s' "$PLIST_XML" | plutil -extract TeamIdentifier.0 raw -)"
PROFILE_NAME="$(printf '%s' "$PLIST_XML" | plutil -extract Name raw -)"

# Personal Team profiles are "Xcode managed" — export must use automatic signingStyle.
cat > "$OUT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>development</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>automatic</string>
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
EOF

echo "Wrote ${OUT} (team=${TEAM_ID}, profile=${PROFILE_NAME}, signing=automatic)"
