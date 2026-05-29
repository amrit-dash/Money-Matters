# Xcode setup without the extra ~10 GB download

You installed **Xcode 26.5**. It already ships the **device** iOS SDK (`iphoneos26.5`). The large optional download in Xcode Settings is usually the **iOS Simulator runtime** — you do **not** need it to:

- Read your **Team ID**
- Export a **Development** certificate / provisioning profile
- Run `flutter build ipa` for a **physical iPhone**

You **do** need the Simulator runtime only if you want `flutter run` on an iOS Simulator.

---

## One-time switch (2 commands)

Your Mac may still point at Command Line Tools. Point at full Xcode once:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

Verify:

```bash
xcodebuild -version
# Xcode 26.5 …

xcodebuild -showsdks | grep iphoneos
# iphoneos26.5  ← enough for device IPA
```

`flutter doctor` may show a warning about **Simulator runtimes** — ignore that for sideload/IPA work.

---

## Get Team ID (5 minutes, no Simulator download)

1. Open **Xcode** (first launch finishes components that ship with the app — not the Simulator runtime).
2. **Xcode → Settings → Accounts** → sign in with your Apple ID.
3. Select your **Personal Team** — on Xcode 26 the Team ID may **not** appear on this screen. Use Terminal instead:

```bash
./scripts/apple_team_id.sh
```

That reads `~/Library/Preferences/com.apple.dt.Xcode.plist` after you sign in (same place Xcode caches `IDEProvisioningTeamByIdentifier`).

**Alternative UI:** open `ios/Runner.xcworkspace` → **Runner** target → **Signing & Capabilities** → Team dropdown often shows `Personal Team (XXXXXXXXXX)`.

Or from Terminal after you have at least one provisioning profile:

```bash
./scripts/apple_team_id.sh
```

---

## Optional: local IPA (same SDK, no Simulator)

Prerequisites: `GoogleService-Info.plist`, CocoaPods, Team selected in Xcode for Runner.

```bash
cd "/Users/amrit/Downloads/DEV/Mobile App/Money Matters"
open ios/Runner.xcworkspace
# Runner → Signing & Capabilities → Team: Personal Team → Automatic signing
```

Edit `ios/ExportOptions.plist` → replace `YOUR_TEAM_ID` with your Team ID, then:

```bash
./scripts/build_ipa.sh
```

**Recommended for you:** still use **GitHub Actions** for the IPA so your Mac does not need a full local compile every time. Use Xcode locally only for Team ID, signing assets, and App Check registration.

---

## App Check (after Team ID)

1. [Firebase App Check](https://console.firebase.google.com/project/money-matters-amrit/appcheck) → iOS app → **App Attest** → paste Team ID → Save (skip DeviceCheck on free account).
2. Add a **debug token** (`uuidgen`) if you test debug builds from Xcode.
3. Install a signed build on your **physical iPhone** once with App Check still **Unenforced**.
4. Rebuild with App Check on: `--dart-define=ENABLE_APP_CHECK=true`
5. When Auth + Firestore work on device → **Enforce** those APIs (not `ingestSms`).

See [APP-CHECK-FREE-APPLE-ACCOUNT.md](APP-CHECK-FREE-APPLE-ACCOUNT.md).

---

## Then: GitHub signing secrets

[SETUP-SIGNING.md](SETUP-SIGNING.md) — export `.p12` + `.mobileprovision`, run `./scripts/encode_signing_secrets.sh`, run **Actions → iOS IPA**.
