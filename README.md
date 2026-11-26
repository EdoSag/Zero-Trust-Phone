# Zero-Trust Phone

A private dialer for Android. It replaces the built-in Phone app: dialpad,
in-call screen, call history, favorites and blocked numbers, with caller
names from your end-to-end encrypted [ZT
Contacts](https://github.com/EdoSag/Zero-Trust-Contacts) instead of Google's
contacts. On the phone it is called **ZT Phone**; in stores and on release
pages, **Zero-Trust Phone**. Same account, settings and look as the other
Zero-Trust apps, built on
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core). Part of the
[Zero-Trust suite](https://zerotrust.bz).

Android only: iOS doesn't let an app replace the Phone app.

## What it does

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
- **Real-time text and video calls (P12).** When the carrier offers RTT,
  the call screen turns into a live chat: each letter goes out as it's
  typed (`Call.RttCall`), and Settings > Accessibility and video can start
  every call with RTT. Carrier video calls (ViLTE) draw the other
  person's video and the camera preview into Flutter textures through
  `InCallService.VideoCall`. Both go over the carrier's network only;
  nothing is stored. TTY mode can only be changed by the phone's built-in
  Phone app, so Settings links to its screen when there is one.
- **Recent calls widget (W11).** A home screen widget reads Android's call
  log; it shows only a lock and the missed-call count until "Show details
  on the home screen" is on. Private contacts never show.
- **Signed spam list (P24).** The weekly `Spam list` workflow
  (`tool/build_spam_list.py`) builds a list from FTC Do Not Call complaints
  and `spam/reported.tsv`, signs it with the blocklist key
  (`BLOCKLIST_SIGNING_KEY` secret) and publishes it on the `spam-list`
  release. The app checks the signature and looks numbers up on the phone.
- **Recording and transcripts (P19-P21).** Record call writes the sound in
  Keystore-sealed pieces (`Recordings.kt`). Android usually gives ordinary
  apps silence during calls; the recorder notices and stops. Transcripts
  of recordings and visual voicemail run on the phone with whisper.cpp
  (`android/whisper`, the same module as ZT Keyboard) and the models from
  ZT Keyboard's `voice-models` release, and can be saved to ZT Notes.
- No database changes: Phone uses the existing `vault_items` table and
  sign-in. Old and new accounts sign in exactly as in the other apps.

## Privacy

Like every Zero-Trust app, it is zero-knowledge: your data is encrypted on
your device, with keys made from your password, before anything is sent.
The server stores only ciphertext and your password itself is never
sent, so neither we nor anyone who breaks into the server can read your
data. The recovery key shown at sign-up is the only way back in if you
forget the password. How the keys work:
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core#key-hierarchy) and
[zerotrust.bz/security](https://zerotrust.bz/security/).

- Call history and blocked numbers stay in Android's own call log; backing
  the history up to your account is opt-in and end-to-end encrypted.
- The call screen runs without the account, the vault or the network.
  Caller names reach it only in memory while the vault is unlocked.
- Call protection works while the app is locked from Keystore-keyed HMACs
  of contact numbers, never plain numbers.
- Recordings are sealed on the phone, and transcripts are made on the
  phone.
- Real-time text and video calls go over the carrier's network only;
  nothing is stored.

## One account, one core

One Zero-Trust account opens every app in the suite. Sign-in, unlock
(fingerprint or face, auto-lock), the recovery key, settings, the look,
sync and languages come from
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core), so they work
the same in every app. Accounts made before the core still sign in and
see their data.

## Install

Android: get the latest signed APK from this repository's
[Releases](https://github.com/EdoSag/Zero-Trust-Phone/releases/latest),
or from [zerotrust.bz/install](https://zerotrust.bz/install/#phone),
which also shows each file's SHA-256, the signing fingerprint and an
Obtainium link. GitHub Releases are the main way the apps are published.

Builds from GitHub check for a newer release themselves (Settings > About,
one anonymous request a day, can be turned off). Every Zero-Trust app is signed
with the same key, and Android only installs an update signed with it.

## Languages

English and Hebrew, with right-to-left layout. Choose under
Settings > Appearance > Language.

## Build from source

Flutter 3.47.9, the version CI pins (3.50 deprecates `material.dart` and
fails analyze).

First create a file named `.env` in the project folder. It is not committed
(CI writes its own) and it is bundled into the APK, so it holds public client
values only, never a service-role key:

```
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<publishable key>
```

Then:

```bash
flutter pub get
dart run zt_release_checks --app phone   # shared release checks
flutter analyze && flutter test test/
flutter run
```

Never add `cryptography_flutter`: it breaks the core's key derivation and
sign-in fails.

Launcher icons are drawn from the suite's brand mark:
`flutter test tool/launcher_icon_test.dart`.

## Branches and releases

Work happens on `Dev`: pull requests target `Dev`, never `main`, and get a
test build. A release is one `Dev` → `main` pull request. Every push to
`main` runs the suite's release checks, builds a signed APK and a Google Play bundle
and publishes them as a GitHub Release named "Zero-Trust Phone"
(`.github/workflows/android-apk.yml`). The workflow needs the repository
secrets `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`, the
keystore shared by all Zero-Trust apps.

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
4. **Camera**: asked for only when a video call starts (P12). The
   camera stays with the carrier's video call; no photos or video are
   saved or uploaded.
5. **Data safety**: call history and contacts stay on the device or
   end-to-end encrypted; nothing readable reaches the server.

Sideloaded APKs from GitHub Releases need none of this.

## Support and security

- Help centre: [zerotrust.bz/help](https://zerotrust.bz/help/). Questions and
  account deletion: support@zerotrust.bz.
- Security problems: please report them privately to cyber@zerotrust.bz. What
  the encryption does and doesn't protect against is on
  [zerotrust.bz/security](https://zerotrust.bz/security/).
- [Privacy policy](https://zerotrust.bz/privacy/) and
  [terms](https://zerotrust.bz/terms/).

## License

Copyright (C) 2026 Edo Sagron (https://zerotrust.bz)

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
