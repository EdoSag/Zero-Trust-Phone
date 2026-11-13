import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// Phone's own synced items: end-to-end encrypted like every Zero-Trust
/// app's data, under the Phone app key, so they follow the account to a
/// new phone.

/// Per-contact call settings (P6, P7). Item id = the ZT Contacts id.
class ContactCallSettings {
  const ContactCallSettings({
    required this.contactId,
    this.ringtone,
    this.ringtoneTitle,
    this.toVoicemail = false,
    this.accountId,
    this.accountLabel,
    this.hideCallerId = false,
  });

  final String contactId;

  /// Android ringtone URI; null = the phone's ringtone.
  final String? ringtone;
  final String? ringtoneTitle;

  /// Calls from this contact go straight to voicemail.
  final bool toVoicemail;

  /// The SIM to call this contact with; null = ask or the phone's default.
  final String? accountId;
  final String? accountLabel;

  /// P22: calls to this contact hide my number (where the carrier allows).
  final bool hideCallerId;

  bool get isEmpty =>
      ringtone == null && !toVoicemail && accountId == null && !hideCallerId;

  ContactCallSettings copyWith({
    String? Function()? ringtone,
    String? Function()? ringtoneTitle,
    bool? toVoicemail,
    String? Function()? accountId,
    String? Function()? accountLabel,
    bool? hideCallerId,
  }) => ContactCallSettings(
    contactId: contactId,
    ringtone: ringtone != null ? ringtone() : this.ringtone,
    ringtoneTitle: ringtoneTitle != null ? ringtoneTitle() : this.ringtoneTitle,
    toVoicemail: toVoicemail ?? this.toVoicemail,
    accountId: accountId != null ? accountId() : this.accountId,
    accountLabel: accountLabel != null ? accountLabel() : this.accountLabel,
    hideCallerId: hideCallerId ?? this.hideCallerId,
  );
}

final ZtCollection<ContactCallSettings> contactSettingsCollection =
    ZtCollection<ContactCallSettings>(
      kind: 'contact_call_settings',
      version: 1,
      fromJson: (String id, Map<String, Object?> j, DateTime _) =>
          ContactCallSettings(
            contactId: id,
            ringtone: j['ringtone'] as String?,
            ringtoneTitle: j['ringtoneTitle'] as String?,
            toVoicemail: j['toVoicemail'] == true,
            accountId: j['accountId'] as String?,
            accountLabel: j['accountLabel'] as String?,
            hideCallerId: j['hideCallerId'] == true,
          ),
      toJson: (ContactCallSettings s) => <String, Object?>{
        'ringtone': s.ringtone,
        'ringtoneTitle': s.ringtoneTitle,
        'toVoicemail': s.toVoicemail,
        'accountId': s.accountId,
        'accountLabel': s.accountLabel,
        'hideCallerId': s.hideCallerId,
      },
      idOf: (ContactCallSettings s) => s.contactId,
    );

/// A number with what to send after it connects (P15): a menu choice, a
/// conference code or a voicemail PIN, saved so it is one tap. Kept for a
/// contact ([contactId]) or for the number alone.
class DialShortcut {
  const DialShortcut({
    required this.id,
    required this.label,
    required this.number,
    required this.postDial,
    this.contactId,
  });

  final String id;
  final String label;

  /// The number to call, without what follows.
  final String number;

  /// What follows: `,` waits about 3 seconds, `;` waits for a tap, then
  /// digits, `*` and `#` are sent as tones.
  final String postDial;
  final String? contactId;

  /// What Android dials: the number with its pauses and tones.
  String get dialString => '$number$postDial';
}

final ZtCollection<DialShortcut> dialShortcutCollection =
    ZtCollection<DialShortcut>(
      kind: 'dial_shortcut',
      version: 1,
      fromJson: (String id, Map<String, Object?> j, DateTime _) => DialShortcut(
        id: id,
        label: j['label'] as String? ?? '',
        number: j['number'] as String? ?? '',
        postDial: j['postDial'] as String? ?? '',
        contactId: j['contactId'] as String?,
      ),
      toJson: (DialShortcut s) => <String, Object?>{
        'label': s.label,
        'number': s.number,
        'postDial': s.postDial,
        'contactId': s.contactId,
      },
      idOf: (DialShortcut s) => s.id,
    );

/// Speed dial (P8): long-press 2 to 9 on the dialpad.
class SpeedDial {
  const SpeedDial({
    required this.digit,
    required this.number,
    required this.name,
    this.contactId,
  });

  final int digit;
  final String number;
  final String name;
  final String? contactId;

  static String idFor(int digit) => 'speed_dial_$digit';
}

final ZtCollection<SpeedDial> speedDialCollection = ZtCollection<SpeedDial>(
  kind: 'speed_dial',
  version: 1,
  fromJson: (String id, Map<String, Object?> j, DateTime _) => SpeedDial(
    digit: (j['digit'] as num).toInt(),
    number: j['number'] as String? ?? '',
    name: j['name'] as String? ?? '',
    contactId: j['contactId'] as String?,
  ),
  toJson: (SpeedDial s) => <String, Object?>{
    'digit': s.digit,
    'number': s.number,
    'name': s.name,
    'contactId': s.contactId,
  },
  idOf: (SpeedDial s) => SpeedDial.idFor(s.digit),
);

/// Call protection settings (P1). One item, synced so a new phone gets
/// the same rules.
class CallProtection {
  const CallProtection({
    this.unknownCallers = UnknownCallers.ring,
    this.blockHidden = false,
    this.blockedPrefixes = const <String>[],
    this.backupHistory = false,
  });

  final UnknownCallers unknownCallers;
  final bool blockHidden;

  /// "+1900", "+44" (a whole country), "0870"...
  final List<String> blockedPrefixes;

  /// P9: keep an encrypted copy of the call history in the account.
  final bool backupHistory;

  static const String id = 'phone_settings';

  CallProtection copyWith({
    UnknownCallers? unknownCallers,
    bool? blockHidden,
    List<String>? blockedPrefixes,
    bool? backupHistory,
  }) => CallProtection(
    unknownCallers: unknownCallers ?? this.unknownCallers,
    blockHidden: blockHidden ?? this.blockHidden,
    blockedPrefixes: blockedPrefixes ?? this.blockedPrefixes,
    backupHistory: backupHistory ?? this.backupHistory,
  );
}

enum UnknownCallers {
  ring('Ring as usual'),
  silence('Silence (they still show in Recents)'),
  voicemail('Send to voicemail');

  const UnknownCallers(this.label);
  final String label;
}

final ZtCollection<CallProtection> protectionCollection =
    ZtCollection<CallProtection>(
      kind: 'phone_settings',
      version: 1,
      fromJson: (String id, Map<String, Object?> j, DateTime _) =>
          CallProtection(
            unknownCallers: UnknownCallers.values.firstWhere(
              (UnknownCallers u) => u.name == j['unknownCallers'],
              orElse: () => UnknownCallers.ring,
            ),
            blockHidden: j['blockHidden'] == true,
            blockedPrefixes: <String>[
              for (final Object? p
                  in (j['blockedPrefixes'] as List<Object?>?) ?? <Object?>[])
                if (p is String) p,
            ],
            backupHistory: j['backupHistory'] == true,
          ),
      toJson: (CallProtection p) => <String, Object?>{
        'unknownCallers': p.unknownCallers.name,
        'blockHidden': p.blockHidden,
        'blockedPrefixes': p.blockedPrefixes,
        'backupHistory': p.backupHistory,
      },
      idOf: (CallProtection _) => CallProtection.id,
    );

/// One call in the encrypted history backup (P9).
class BackedUpCall {
  const BackedUpCall({
    required this.id,
    required this.number,
    required this.type,
    required this.date,
    required this.durationSeconds,
  });

  final String id;
  final String number;

  /// Android's `CallLog.Calls.TYPE`.
  final int type;
  final DateTime date;
  final int durationSeconds;
}

final ZtCollection<BackedUpCall> backedUpCallsCollection =
    ZtCollection<BackedUpCall>(
      kind: 'call_history',
      version: 1,
      fromJson: (String id, Map<String, Object?> j, DateTime _) => BackedUpCall(
        id: id,
        number: j['number'] as String? ?? '',
        type: (j['type'] as num?)?.toInt() ?? 1,
        date: DateTime.fromMillisecondsSinceEpoch((j['date'] as num).toInt()),
        durationSeconds: (j['duration'] as num?)?.toInt() ?? 0,
      ),
      toJson: (BackedUpCall c) => <String, Object?>{
        'number': c.number,
        'type': c.type,
        'date': c.date.millisecondsSinceEpoch,
        'duration': c.durationSeconds,
      },
      idOf: (BackedUpCall c) => c.id,
    );

/// Phone's own store, open while unlocked.
final phoneStoreProvider = FutureProvider<ZtLocalStore>(
  (ref) async => (await ref.watch(ztLocalStoreProvider.future)) as ZtLocalStore,
);

StreamProvider<List<T>> _watch<T>(ZtCollection<T> c) =>
    StreamProvider<List<T>>((ref) async* {
      final ZtLocalStore store = await ref.watch(phoneStoreProvider.future);
      yield* c.watch(store);
    });

final contactSettingsProvider = _watch(contactSettingsCollection);
final speedDialsProvider = _watch(speedDialCollection);
final dialShortcutsProvider = _watch(dialShortcutCollection);
final _protectionList = _watch(protectionCollection);

final callProtectionProvider = Provider<CallProtection>((ref) {
  final List<CallProtection>? all = ref.watch(_protectionList).value;
  return (all == null || all.isEmpty) ? const CallProtection() : all.first;
});

/// Saves Phone's own items.
class PhoneData {
  PhoneData(this.ref);
  final Ref ref;

  Future<void> _save<T>(ZtCollection<T> c, T value) async {
    final ZtLocalStore store = await ref.read(phoneStoreProvider.future);
    await c.save(ref.read(ztSyncControllerProvider.notifier), store, value);
  }

  Future<void> _delete<T>(ZtCollection<T> c, String id) =>
      c.delete(ref.read(ztSyncControllerProvider.notifier), id);

  Future<void> saveContactSettings(ContactCallSettings s) => s.isEmpty
      ? _delete(contactSettingsCollection, s.contactId)
      : _save(contactSettingsCollection, s);

  Future<void> saveSpeedDial(SpeedDial s) => _save(speedDialCollection, s);

  Future<void> clearSpeedDial(int digit) =>
      _delete(speedDialCollection, SpeedDial.idFor(digit));

  Future<void> saveDialShortcut(DialShortcut s) =>
      _save(dialShortcutCollection, s);

  Future<void> deleteDialShortcut(String id) =>
      _delete(dialShortcutCollection, id);

  Future<void> saveProtection(CallProtection p) =>
      _save(protectionCollection, p);

  Future<void> saveCall(BackedUpCall c) => _save(backedUpCallsCollection, c);

  Future<void> deleteCall(String id) => _delete(backedUpCallsCollection, id);

  /// The saved protection settings, read straight from the store (the
  /// provider may not have loaded yet right after unlock).
  Future<CallProtection> protection() async =>
      await protectionCollection.get(
        await ref.read(phoneStoreProvider.future),
        CallProtection.id,
      ) ??
      const CallProtection();

  Future<List<BackedUpCall>> backedUpCalls() async =>
      backedUpCallsCollection.list(await ref.read(phoneStoreProvider.future));
}

final phoneDataProvider = Provider<PhoneData>((ref) => PhoneData(ref));
