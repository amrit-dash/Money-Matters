# Firebase App Check

App Check reduces abuse of Firebase backends (Firestore, Auth) from unauthorized clients.

## What is protected

| Surface | App Check | Notes |
|---------|-----------|--------|
| Flutter app → Auth | Yes | SDK sends App Check token after `AppCheckBootstrap.activate()` |
| Flutter app → Firestore | Yes | Same |
| Shortcuts → `ingestSms` HTTP | **No** | Shortcuts cannot attach App Check; uses **device Bearer token** + idempotency |
| GitHub Actions / CI | Debug provider | Register debug token in Console for local builds |

## Firebase Console (you — one-time)

1. [App Check](https://console.firebase.google.com/project/money-matters-amrit/appcheck) → **Apps** → select **Money Matters iOS**.
2. Register provider:
   - **App Attest** (preferred on iOS 14+)
   - Enable **DeviceCheck** as fallback (same screen).
3. Under **APIs**, click **Enforce** for:
   - **Cloud Firestore**
   - **Authentication** (Identity Toolkit)
   - **Firebase Storage** (if used later)
4. Do **not** enforce App Check on the **`ingestSms`** HTTP function — Shortcuts would break.

### Debug builds (Xcode Run, Simulator)

1. Run the app once in **debug** (`AppleProvider.debug` is automatic in debug mode).
2. Console → App Check → your iOS app → **Manage debug tokens** → copy the token from Xcode logs (search `Firebase App Check Debug Token`).
3. Register that token in the Console.

## Shortcuts ingest security (without App Check)

- Per-device secret in `users/{uid}/device_tokens/{deviceId}` (SHA-256 hash stored).
- `Authorization: Bearer <raw-token>` on every POST.
- Idempotency key prevents replay duplicates.
- Firestore rules scope all data to `request.auth.uid`.

## Code

- Activation: `lib/core/app_check/app_check_bootstrap.dart`
- Called from `lib/main.dart` immediately after `Firebase.initializeApp`.
