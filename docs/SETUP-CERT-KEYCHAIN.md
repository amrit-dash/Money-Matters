# Fix signing: certificate WITH private key (no Xcode delete button)

> **STOP — free Personal Team account?**  
> The Apple Developer **website** will show “Access Unavailable” for Certificates.  
> **Do not use this doc.** Use **[SETUP-SIGNING-FREE-ACCOUNT.md](SETUP-SIGNING-FREE-ACCOUNT.md)** instead (Xcode only).

---

# Paid Apple Developer Program only ($99/year)

Your screenshot shows:

- **29/05/26** — active-looking **Apple Development** cert  
- **10/04/26** — grey **Not in Keychain** (harmless; ignore it)

**There is no − button in newer Xcode** until a cert is **Revoked** on the website. You do **not** need to delete anything to proceed.

The real blocker: macOS still has **no private key**, so signing fails. Use this Keychain + web flow once.

---

## Part 1 — Create a cert that includes a private key (~5 min)

### 1. Create a certificate signing request (CSR)

1. Open **Keychain Access** (Spotlight).
2. Menu **Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority…**
3. User Email: `amrit.dash60@gmail.com`
4. Common Name: `Amrit Money Matters Dev`
5. **Saved to disk** → save as `MoneyMatters.certSigningRequest`
6. **Continue** → Done

This creates a **private key** in your login keychain (required).

### 2. Create the Apple Development certificate on the web

1. [Certificates → +](https://developer.apple.com/account/resources/certificates/add)
2. **Apple Development** → Continue
3. Upload `MoneyMatters.certSigningRequest` → Continue
4. **Download** `development.cer`

### 3. Install the certificate

Double-click `development.cer` (installs into Keychain and links to the private key from step 1).

### 4. Verify (Terminal)

```bash
cd "/Users/amrit/Downloads/DEV/Mobile App/Money Matters"
./scripts/ios_signing_doctor.sh
```

You need: **✅ Signing identity found** (not 0 valid identities).

---

## Part 2 — Provisioning profile (web)

Follow [SETUP-SIGNING-PORTAL.md](SETUP-SIGNING-PORTAL.md) sections 1–4 (App ID, device, profile, double-click to install).

Run `./scripts/ios_signing_doctor.sh` again → **✅ Provisioning profile**.

---

## Part 3 — GitHub IPA

1. Keychain Access → **My Certificates** → **Apple Development** → expand ▶ (**private key** visible)  
2. Select certificate → **File → Export Items…** → `MoneyMatters-Dev.p12` + password  
3. Run:

```bash
./scripts/upload_signing_to_github.sh ~/Desktop/MoneyMatters-Dev.p12 ~/Downloads/YourProfile.mobileprovision
```

4. GitHub → **Actions → iOS IPA → Run workflow**

---

## Optional — clean up the grey Xcode row later

Only if you want the old cert gone from the list:

1. [Certificates list](https://developer.apple.com/account/resources/certificates/list)  
2. Revoke the **old** Development cert (April one), **not** the new one you just created  
3. In Xcode **Manage Certificates**, **Control-click** the revoked row → **Delete Certificate** (enabled only after revoke)

You can skip this entirely.
