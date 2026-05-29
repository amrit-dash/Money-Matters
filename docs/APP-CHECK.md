# Firebase App Check (disabled — Personal Team)

App Check is **off** in this project. See **[APP-CHECK-FREE-APPLE-ACCOUNT.md](APP-CHECK-FREE-APPLE-ACCOUNT.md)** for the full Personal Team vs paid program breakdown.

**Bottom line:**

- **App Attest in provisioning:** not available on a free Personal Team.
- **App Check with App Attest:** not viable for your signed sideload IPA today.
- **App Check with Debug tokens:** possible for testing only; optional.
- **No App Check:** fine for personal MVP (device tokens + Firestore rules + Auth).

Remove old App Check app entries in Firebase Console if the deleted iOS app still appears under App Check providers.
