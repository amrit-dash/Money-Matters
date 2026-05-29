# App Check on a free Personal Team (Xcode)

## Can we use App Attest in provisioning?

**No.** Not on a free **Personal Team** (Xcode “Personal Team” / on-device testing).

Evidence:

1. **Your Xcode error** (when `com.apple.developer.devicecheck.appattest-environment` was in entitlements):  
   *“Personal development teams … do not support the App Attest capability.”*

2. **Apple’s capability matrix** — [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios/): **App Attest** is listed only for **ADP** (paid Apple Developer Program, $99/year), not for the free “Apple Developer” agreement or Personal Team workflows.

3. **Provisioning** — App Attest is a **managed capability** that must appear in the **provisioning profile**. Personal Team profiles cannot include that entitlement, so signed IPAs from your current setup cannot use the App Attest **SDK path** for App Check.

**Paid program ($99/year):** You can enable App Attest on the App ID, add the entitlement, and use App Attest with Firebase App Check on device.

---

## Can we use Firebase App Check in the app?

| Approach | Free Personal Team? | Notes |
|----------|---------------------|--------|
| **No App Check** (current) | **Yes** | Recommended for MVP. Shortcuts use device tokens; Firestore uses rules + Auth. |
| **App Attest provider** | **No** (for real signed builds) | Needs App Attest in provisioning → blocked on Personal Team. Console registration alone is not enough. |
| **DeviceCheck provider** | **No** | Needs paid program + `.p8` key from developer.apple.com/keys. |
| **Debug provider** | **Yes** (dev / testing only) | No App Attest entitlement. Register a debug token in Firebase Console; use `AppleProvider.debug` in debug builds or `--dart-define` for test IPAs. **Not** a substitute for production hardening on a sideload release. |

Firebase’s [App Attest codelab](https://firebase.google.com/codelabs/app-attest) assumes you can configure app capabilities and provisioning (paid-program style). That does not match Personal Team limits.

---

## Recommendation (unchanged)

Keep **App Check disabled** in the app and **Unenforced** in Firebase for Auth/Firestore until you join the paid program (if you ever want App Attest + enforcement).

Optional for local debugging only: re-add `firebase_app_check`, use **Debug** provider + debug token — not required for Money Matters MVP.

---

## If you upgrade to the paid program later

1. Enable **App Attest** on App ID `com.amritdash.moneymatters` in Certificates, Identifiers & Profiles.
2. Add App Attest capability + `production` environment in `Runner.entitlements`.
3. Re-add `firebase_app_check` and `AppCheckBootstrap` with `AppleProvider.appAttest`.
4. Register App Attest in Firebase (Team ID `F4TFHKUQDA`).
5. Test on a physical iPhone, then **Enforce** Auth/Firestore (not `ingestSms`).
