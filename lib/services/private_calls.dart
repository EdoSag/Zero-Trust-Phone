import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/services/history_backup.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';

/// Private call log mode (P23): chosen contacts' calls are kept only in the
/// vault. The Android side takes them out of the shared call log right
/// after Telecom writes them; this moves them into the vault.
class PrivateCalls {
  PrivateCalls(this.ref);
  final Ref ref;

  /// Moves the calls the Android side is holding into the vault. Returns
  /// how many.
  Future<int> collect() async {
    final List<Map<Object?, Object?>> taken = await ref
        .read(telecomProvider)
        .takePrivateCalls();
    final PhoneData data = ref.read(phoneDataProvider);
    for (final Map<Object?, Object?> m in taken) {
      final String number = m['number'] as String? ?? '';
      final int type = (m['type'] as num?)?.toInt() ?? 1;
      final DateTime date = DateTime.fromMillisecondsSinceEpoch(
        (m['date'] as num? ?? 0).toInt(),
      );
      await data.savePrivateCall(
        BackedUpCall(
          id: await HistoryBackup.idFor(number, date, type),
          number: number,
          type: type,
          date: date,
          durationSeconds: (m['duration'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return taken.length;
  }

  /// Turning private mode on for [contact]: their calls already in the
  /// shared call log move into the vault too. Returns how many.
  Future<int> moveExisting(PhoneContact contact) async {
    final Telecom telecom = ref.read(telecomProvider);
    final List<CallLogEntry> theirs = (await telecom.callLog(limit: 5000))
        .where(
          (CallLogEntry e) =>
              contact.phones.any((String p) => PhoneNumbers.same(p, e.number)),
        )
        .toList();
    if (theirs.isEmpty) return 0;
    final PhoneData data = ref.read(phoneDataProvider);
    for (final CallLogEntry e in theirs) {
      await data.savePrivateCall(
        BackedUpCall(
          id: await HistoryBackup.idFor(e.number, e.date, e.androidType),
          number: e.number,
          type: e.androidType,
          date: e.date,
          durationSeconds: e.duration.inSeconds,
        ),
      );
    }
    // Saved first, then deleted, so nothing is lost on a failure.
    await telecom.deleteCalls(<int>[for (final CallLogEntry e in theirs) e.id]);
    await ref.read(historyBackupProvider).forget(theirs).catchError((_) {});
    ref.invalidate(callLogProvider);
    return theirs.length;
  }

  /// Deletes [calls] wherever they are kept: Android's log or the vault.
  Future<void> delete(List<CallLogEntry> calls) async {
    final List<int> shared = <int>[
      for (final CallLogEntry c in calls)
        if (!c.isPrivate) c.id,
    ];
    if (shared.isNotEmpty) {
      await ref.read(telecomProvider).deleteCalls(shared);
      await ref
          .read(historyBackupProvider)
          .forget(<CallLogEntry>[
            for (final CallLogEntry c in calls)
              if (!c.isPrivate) c,
          ])
          .catchError((_) {});
      ref.invalidate(callLogProvider);
    }
    final PhoneData data = ref.read(phoneDataProvider);
    for (final CallLogEntry c in calls) {
      if (c.privateId case final String id) await data.deletePrivateCall(id);
    }
  }

  /// "Keep call history" applies to private calls too.
  Future<void> deleteBefore(DateTime cutoff) async {
    final PhoneData data = ref.read(phoneDataProvider);
    for (final BackedUpCall c in await data.privateCalls()) {
      if (c.date.isBefore(cutoff)) await data.deletePrivateCall(c.id);
    }
  }

  /// Lookup keys of contacts in private mode, so a restored backup doesn't
  /// put their calls back into the shared log.
  Future<Set<String>> privateKeys() async {
    final ContactDirectory dir = ref.read(contactDirectoryProvider);
    final Set<String> ids = <String>{
      for (final ContactCallSettings s
          in await ref.read(phoneDataProvider).contactSettings())
        if (s.privateLog) s.contactId,
    };
    return <String>{
      for (final PhoneContact c in dir.contacts)
        if (ids.contains(c.id))
          for (final String p in c.phones) PhoneNumbers.lookupKey(p),
    };
  }
}

final privateCallsServiceProvider = Provider<PrivateCalls>(
  (ref) => PrivateCalls(ref),
);

/// A vault-kept call as a history row.
CallLogEntry privateEntry(BackedUpCall c) => CallLogEntry(
  id: 0,
  number: c.number,
  type: CallType.fromAndroid(c.type),
  date: c.date,
  duration: Duration(seconds: c.durationSeconds),
  privateId: c.id,
);

/// Android's call log and the vault's private calls, newest first.
List<CallLogEntry> mergeCalls(
  List<CallLogEntry> shared,
  List<BackedUpCall> private,
) {
  if (private.isEmpty) return shared;
  final List<CallLogEntry> all = <CallLogEntry>[
    ...shared,
    for (final BackedUpCall c in private) privateEntry(c),
  ]..sort((CallLogEntry a, CallLogEntry b) => b.date.compareTo(a.date));
  return all;
}

/// Every call Recents and the stats show: the shared log plus the vault's
/// private calls. Loads with the shared log; private ones join once the
/// vault store is open.
final allCallsProvider = Provider<AsyncValue<List<CallLogEntry>>>((ref) {
  final AsyncValue<List<CallLogEntry>> shared = ref.watch(callLogProvider);
  final List<BackedUpCall> private =
      ref.watch(privateCallsProvider).value ?? const <BackedUpCall>[];
  return shared.whenData((List<CallLogEntry> s) => mergeCalls(s, private));
});
