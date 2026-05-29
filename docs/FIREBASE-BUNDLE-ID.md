# Bundle ID — `com.amritdash.moneymatters`

**Active Firebase iOS app:** `1:960400349210:ios:4c539be1d84a6aeb2399a3`  
**Bundle ID:** `com.amritdash.moneymatters`

Configured in repo:

- `ios/Runner/GoogleService-Info.plist`
- `lib/core/config/firebase_options.dart`
- `ios/Runner/Info.plist` (Google Sign-In URL scheme)
- GitHub secret `GOOGLE_SERVICE_INFO_PLIST_BASE64`

## Remove old iOS app (manual — MCP/CLI cannot delete)

In [Firebase Console → Project settings](https://console.firebase.google.com/project/money-matters-amrit/settings/general), delete the old app with bundle **`com.moneymatters.moneyMatters`** (`…29b97738f2d83a952399a3`).

**App Check:** not used; remove any old iOS app from App Check providers if listed.
