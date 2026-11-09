# Zero-Trust Phone

A private dialer for Android (on the phone: **ZT Phone**). It replaces the
built-in Phone app: dialpad, in-call screen, call history, favorites and
blocked numbers, with caller names from your end-to-end encrypted
[ZT Contacts](https://github.com/EdoSag/Zero-Trust-Contacts) instead of
Google's contacts. Same account, settings and look as the other Zero-Trust
apps, built on [Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core).

Android only: iOS doesn't let an app replace the Phone app.

## How it works

- **Default Phone app.** ZT Phone asks for Android's Phone role
  (`RoleManager.ROLE_DIALER`). Telecom then binds `ZtInCallService` for
  every call, and the system keeps playing the ringtone.
- **In-call screen without unlocking.** `CallActivity` runs its own Flutter
  engine with the `callMain` entry point (lib/call/in_call_app.dart): no
  account, vault or network, so a call shows at once, over the lock screen.
  Answer, decline, hang up, mute, speaker or Bluetooth, hold, keypad tones,
  add a call, swap and merge. The screen turns off near the ear.
- **Caller names.** While the vault is unlocked, the app hands the in-call
  screen a number-to-name map from ZT Contacts, held in memory only. When
  it's locked (or the app was closed) names come from the phone's own
  contacts, which includes ZT Contacts' opt-in "Show in Phone and
  Messages" copies.
- **Contacts are read-only.** At unlock Phone derives the Contacts app key
  from the account key and pulls the account's Contacts items into its own
  encrypted local file. A `ReadOnlySyncBackend` makes uploads impossible,
  so Phone can never change the address book. Edits happen in ZT Contacts.
- **Call history and blocking** use Android's own call log and blocked
  numbers list (the system writes calls there whatever app is default).
  Settings > "Keep call history" deletes calls older than 1, 7, 30 or 90
  days each time the app opens.
- No database changes: Phone uses the existing `vault_items` table and
  sign-in. Old and new accounts sign in exactly as in the other apps.

## Google Play

Phone and call-log permissions are restricted on Google Play. Before the
first upload:

1. **Permissions Declaration Form** (Play Console > App content > Sensitive
   permissions): declare `READ_CALL_LOG` and `WRITE_CALL_LOG` under the
   "Default Phone handler" core use. The app must ask to become the
   default Phone app before it uses them, which it does (the banner on the
   home screen and Settings > Default Phone app).
2. A **demo video** of setting ZT Phone as the default Phone app and
   placing/receiving a call, for the review.
3. **Full-screen intent** (Android 14+): declare "calling app" use for
   `USE_FULL_SCREEN_INTENT` in App content.
4. **Data safety**: call history and contacts stay on the device or
   end-to-end encrypted; nothing readable reaches the server.

Sideloaded APKs from GitHub Releases need none of this.

## Build

Like the other apps: push to `main` builds a signed APK release (see
`.github/workflows/android-apk.yml`); the repository needs the
`ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD` secrets, the
same shared keystore as the other apps. Locally, put `SUPABASE_URL` and
`SUPABASE_ANON_KEY` in `.env`, then `flutter run`.

Never add `cryptography_flutter`: it breaks the core's key derivation.

Regenerate the launcher icon with `flutter test tool/launcher_icon_test.dart`.
