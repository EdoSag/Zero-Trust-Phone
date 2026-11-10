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
- **Call protection, on the phone (P1).** `ZtCallScreeningService` silences
  unknown callers or sends them to voicemail, blocks hidden numbers and
  number prefixes or whole countries, and applies per-contact "always send
  to voicemail". It works while ZT Phone is locked: the app hands it the
  rules plus Keystore-keyed HMACs of contact numbers, never plain numbers.
- **Per-contact ringtone, SIM and voicemail (P6, P7), speed dial and quick
  replies (P3, P8)** are encrypted items in the account (`contact_call_settings`,
  `speed_dial`, `phone_settings`). Quick replies stay on the phone because
  the call screen runs locked. Declining with a text uses Telecom's
  `reject(true, text)`, so the app needs no SMS permission.
- **Missed calls and voicemail (P2, P5).** As the default dialer the app
  posts its own missed-call notification (Call back, Message, Add to
  contacts) and the voicemail-waiting one. Hold 1 to call voicemail.
- **Call history backup (P9)** is opt-in: each call is an encrypted
  `call_history` item, trimmed by "Keep call history", and restorable on
  a new phone.
- **Car mode (P11).** In car mode the call screen shows only big Mute and
  audio buttons; Android Auto shows its own call screen through Telecom.
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

## License

Copyright (C) 2026 EdoSag (https://zerotrust.bz)

Zero-Trust is open source under the [GNU Affero General Public License v3.0](LICENSE)
(AGPL-3.0-only), the same licence Signal uses.

- You may use, study, change and share the code, including in your own projects.
- If you share a changed version, or run it for other people over a network, you must
  publish your full source code under the same licence.
- This program comes with no warranty; see the licence for details.

Third-party libraries keep their own licences; the app lists them under
Settings > Open-source licences.

### Name and logo

The AGPL covers the code, not the brand. "Zero-Trust", "ZT", the app names and icons are
reserved. If you publish a fork, give it a different name and icon so nobody mistakes it
for an official Zero-Trust app.

### Servers

The official apps use the Zero-Trust servers. A fork must use its own backend (for
example its own Supabase project) and must not connect to the official servers.

### Contributing

Pull requests are welcome. By sending one you agree that your contribution is licensed
under the AGPL-3.0 and that the copyright holder may also license it under other terms,
including commercially. This keeps the project able to offer paid plans and other licences.
