# Create a provisioning profile on the web (no Runner project)

> **STOP — free Personal Team account?**  
> Use **[SETUP-SIGNING-FREE-ACCOUNT.md](SETUP-SIGNING-FREE-ACCOUNT.md)** (Xcode only). This page requires the **paid** Apple Developer Program.

---

# Paid Apple Developer Program only ($99/year)

Use this when **Download Manual Profiles** in Xcode finishes but nothing appears.

You need a working **Apple Development** certificate first (cert **with private key**). Run:

```bash
./scripts/ios_signing_doctor.sh
```

If it shows **✅ Signing identity**, continue here.

---

## 1. Register the App ID (if needed)

1. [Identifiers](https://developer.apple.com/account/resources/identifiers/list) → **+**
2. **App IDs** → **App** → Continue
3. Description: `Money Matters`
4. Bundle ID: **Explicit** → `com.moneymatters.moneyMatters`
5. Register

(Skip if `com.moneymatters.moneyMatters` already exists in the list.)

---

## 2. Register your iPhone (if needed)

1. [Devices](https://developer.apple.com/account/resources/devices/list) → **+**
2. Name: `My iPhone`
3. UDID: from [get.udid.io](https://get.udid.io) on the phone
4. Continue → Register

---

## 3. Create the development profile

1. [Profiles](https://developer.apple.com/account/resources/profiles/list) → **+**
2. **iOS App Development** → Continue
3. App ID: **com.moneymatters.moneyMatters**
4. Certificate: tick your **Apple Development** cert
5. Devices: tick your iPhone
6. Profile name: `Money Matters Development`
7. **Generate** → **Download** → saves `Money_Matters_Development.mobileprovision` (name may vary)

---

## 4. Install the profile on your Mac

Double-click the downloaded `.mobileprovision` file.

Or:

```bash
open ~/Downloads/*.mobileprovision
```

Verify:

```bash
./scripts/ios_signing_doctor.sh
```

Should show **✅ Provisioning profile**.

---

## 5. Export `.p12` and upload to GitHub

1. **Keychain Access** → **My Certificates** → **Apple Development** → expand ▶ (private key must show) → **File → Export** → `.p12` + password
2. Run:

```bash
cd "/Users/amrit/Downloads/DEV/Mobile App/Money Matters"
./scripts/upload_signing_to_github.sh ~/Desktop/MoneyMatters-Dev.p12 ~/Downloads/Money_Matters_Development.mobileprovision
```

3. GitHub → **Actions → iOS IPA → Run workflow**
