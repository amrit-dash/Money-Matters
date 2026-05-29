# iOS signing — FREE Apple account only (Personal Team)

**You are not on the paid $99/year Apple Developer Program.**

That means:

| Works | Does not work |
|-------|----------------|
| Xcode → Settings → Accounts → **Personal Team** | [developer.apple.com](https://developer.apple.com/account/resources/certificates/list) **Certificates / Identifiers / Profiles** (“Access Unavailable”) |
| Xcode **automatic signing** for your app | Uploading CSR or creating certs on the website |
| Export **.p12** + profile **after Xcode creates them** | `SETUP-CERT-KEYCHAIN.md` / `SETUP-SIGNING-PORTAL.md` (paid-program only) |

GitHub Actions can still build an IPA if you export what **Xcode** creates on your Mac.

### One command (CLI does the rest after you finish 3 Xcode clicks)

```bash
cd "/Users/amrit/Downloads/DEV/Mobile App/Money Matters"
./scripts/setup_ios_signing_free.sh          # clean keychain, flutter pub get, open project
./scripts/setup_ios_signing_free.sh --check  # after Xcode steps A–C
./scripts/setup_ios_signing_free.sh --export # .p12 + profile → GitHub secrets
```

---

## Signing error: “Personal Team does not support App Attest”

The repo had an App Attest entitlement in `ios/Runner/Runner.entitlements`. **Free teams cannot include that** in a provisioning profile. It is removed for sideload builds. Use Firebase App Check **Debug** tokens until you enroll in the paid program (then restore App Attest).

---

## Do I need to download iOS 26.5?

| Goal | Need iOS 26.5 on your Mac? |
|------|----------------------------|
| **Product → Build** in Xcode | **Yes** — Xcode’s “platform support” for iOS 26.5 (device SDK; not the full Simulator runtime, but still a download) |
| **Signing tab turns green** only | Often **no** — after fixing entitlements, try **Download Manual Profiles** without building |
| **GitHub Actions IPA** | **No** — the cloud Mac already has the platform; you only export `.p12` + profile once signing works locally |

Click **Cancel** on the download dialog if you only want to fix signing first, then **Accounts → Download Manual Profiles**.

---

## Step 1 — Install device support (not the Simulator pack) — only for local Build

`flutter` / `xcodebuild` need the **iOS device platform**, not the 10 GB Simulator runtime.

1. **Xcode → Settings → Components** (or **Platforms**)
2. Find **iOS 26.x** for **device** / **platform support** (not “iOS Simulator”)
3. Install if it shows **Get** / **Download**

If everything already shows **Installed**, skip this.

---

## Step 2 — Fix the certificate in Xcode only

Do **not** use the Apple Developer website.

1. **Keychain Access** → **login** → **My Certificates**
2. Delete any **Apple Development: amrit.dash60@gmail.com** rows (and expand ▶ → delete **private key** if present)
3. **Xcode → Settings → Accounts** → your Apple ID → **Manage Certificates…**
4. Click **+** → **Apple Development** (creates cert + private key on **this Mac**)
5. **Done**

Verify:

```bash
cd "/Users/amrit/Downloads/DEV/Mobile App/Money Matters"
./scripts/ios_signing_doctor.sh
```

Need: **✅ Signing identity found**

The grey **Not in Keychain** row in Xcode can stay; ignore it.

---

## Step 3 — Let Xcode create the profile (open the project once)

```bash
cd "/Users/amrit/Downloads/DEV/Mobile App/Money Matters"
open ios/Runner.xcworkspace
```

In Xcode:

1. Left: blue **Runner** (project)
2. **TARGETS → Runner**
3. **Signing & Capabilities**
4. **Automatically manage signing** → **ON**
5. **Team** → **Amrit Dash (Personal Team)**
6. **Bundle Identifier** → `com.amritdash.moneymatters` (see [FIREBASE-BUNDLE-ID.md](FIREBASE-BUNDLE-ID.md) if Firebase still uses the old ID)

Wait for a **green** check / “Signing Certificate: Apple Development…”.

If Xcode asks to **Register Device** or **Enable capability**, accept.

Then: **Xcode → Settings → Accounts** → your account → **Download Manual Profiles** again.

Verify:

```bash
./scripts/ios_signing_doctor.sh
```

Need: **✅ Provisioning profile** for `com.moneymatters.moneyMatters`.

---

## Step 4 — GitHub IPA (export from Keychain)

1. **Keychain Access** → **My Certificates** → **Apple Development** → expand ▶ (must show **private key**)
2. Select certificate → **File → Export Items…** → `MoneyMatters-Dev.p12` + password

3. Copy profile to Desktop:

```bash
PROFILE=$(ls "$HOME/Library/MobileDevice/Provisioning Profiles/"*.mobileprovision 2>/dev/null | head -1)
cp "$PROFILE" ~/Desktop/MoneyMatters.mobileprovision
open ~/Desktop/MoneyMatters.mobileprovision
```

4. Upload secrets:

```bash
./scripts/upload_signing_to_github.sh ~/Desktop/MoneyMatters-Dev.p12 ~/Desktop/MoneyMatters.mobileprovision
```

5. GitHub → **Actions → iOS IPA → Run workflow**

---

## Free-account limits (expect these)

- Provisioning may **expire after ~7 days**; re-export profile and re-run GitHub workflow when install fails.
- Max **3 apps** installed from free signing at once on one device.
- **App Check App Attest** works with Personal Team; **DeviceCheck** does not.

---

## Error: “You already have a current Development certificate…”

Both rows show **Not in Keychain** — Apple has certs on its servers, but this Mac has no private key. **+** will fail until you **revoke** the old ones.

**In the same Manage Certificates window:**

1. **Control-click** the **older** row (e.g. 10/04/26) → **Revoke Certificate** (if shown) → confirm  
2. Control-click that row again → **Delete Certificate** (enabled only after revoke)  
3. Repeat for the other **Not in Keychain** row if **+** still fails  
4. Click **+** → **Apple Development** → should succeed and install cert + private key here  

If **Revoke Certificate** is missing (free account quirk):

1. **Xcode → Settings → Accounts** → select Apple ID → **−** (remove account) → quit Xcode → reopen → add Apple ID again  
2. Or use the Mac that created the April cert: export `.p12` from that machine’s Keychain and skip creating a new cert  

Do **not** use developer.apple.com Certificates (paid program only).

---

## If Step 2 still shows 0 identities

1. Sign **out** of Apple ID in Xcode Settings → Accounts, sign **in** again.
2. **+ → Apple Development** once more.
3. Create a throwaway project in Xcode (**File → New → App**), set Team to Personal Team, plug in iPhone once OR pick **Any iOS Device (arm64)** and **Product → Build** (⌘B). Then retry `./scripts/ios_signing_doctor.sh`.

---

## Local IPA without GitHub (fallback)

If CI signing is too brittle, build on your Mac only:

```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

Requires Step 1–3 green in Xcode first.
