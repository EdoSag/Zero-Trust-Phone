import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/app/history_retention.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/services/private_calls.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';

/// Encrypted call-history backup (P9). Android's call log isn't part of
/// any app's data, so a new phone starts empty; with this on, each call is
/// also kept as an encrypted Phone item in the account, and "Restore"
/// writes them back into the new phone's call history.
class HistoryBackup {
  HistoryBackup(this.ref);
  final Ref ref;

  /// Calls kept in the backup at most (newest first).
  static const int maxCalls = 2000;

  /// The same call gets the same id on every phone, so restoring and
  /// backing up again never duplicates it.
  static Future<String> idFor(String number, DateTime date, int type) async {
    final Hash h = await Sha256().hash(
      utf8.encode(
        '${PhoneNumbers.lookupKey(number)}|${date.millisecondsSinceEpoch ~/ 1000}|$type',
      ),
    );
    final String hex = h.bytes
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'call_${hex.substring(0, 32)}';
  }

  /// Adds calls missing from the backup, and drops ones older than "Keep
  /// call history". Returns how many were added.
  Future<int> backUp({DateTime? now}) async {
    final PhoneData data = ref.read(phoneDataProvider);
    if (!(await data.protection()).backupHistory) return 0;
    final List<CallLogEntry> log = await ref
        .read(telecomProvider)
        .callLog(limit: maxCalls);
    final List<BackedUpCall> stored = await data.backedUpCalls();
    final Set<String> have = <String>{
      for (final BackedUpCall c in stored) c.id,
    };
    int added = 0;
    for (final CallLogEntry e in log) {
      final String id = await idFor(e.number, e.date, e.androidType);
      if (!have.add(id)) continue;
      await data.saveCall(
        BackedUpCall(
          id: id,
          number: e.number,
          type: e.androidType,
          date: e.date,
          durationSeconds: e.duration.inSeconds,
        ),
      );
      added++;
    }
    final int? keepDays = ref.read(historyRetentionProvider);
    if (keepDays != null) {
      final DateTime cutoff = (now ?? DateTime.now()).subtract(
        Duration(days: keepDays),
      );
      for (final BackedUpCall c in stored) {
        if (c.date.isBefore(cutoff)) await data.deleteCall(c.id);
      }
    }
    return added;
  }

  /// Writes the backup into this phone's call history. Returns how many
  /// calls were added.
  Future<int> restore() async {
    // Private contacts' calls (P23) stay out of the shared call log.
    final Set<String> private = await ref
        .read(privateCallsServiceProvider)
        .privateKeys();
    final List<BackedUpCall> calls = <BackedUpCall>[
      for (final BackedUpCall c
          in await ref.read(phoneDataProvider).backedUpCalls())
        if (!private.contains(PhoneNumbers.lookupKey(c.number))) c,
    ];
    final int added = await ref.read(telecomProvider).insertCalls(
      <Map<String, Object?>>[
        for (final BackedUpCall c in calls)
          <String, Object?>{
            'number': c.number,
            'type': c.type,
            'date': c.date.millisecondsSinceEpoch,
            'duration': c.durationSeconds,
          },
      ],
    );
    if (added > 0) ref.invalidate(callLogProvider);
    return added;
  }

  /// Removes calls the user deleted from history from the backup too.
  Future<void> forget(List<CallLogEntry> calls) async {
    final PhoneData data = ref.read(phoneDataProvider);
    if (!(await data.protection()).backupHistory) return;
    for (final CallLogEntry e in calls) {
      await data.deleteCall(await idFor(e.number, e.date, e.androidType));
    }
  }

  /// Turning the backup off deletes it from the account.
  Future<void> deleteAll() async {
    final PhoneData data = ref.read(phoneDataProvider);
    for (final BackedUpCall c in await data.backedUpCalls()) {
      await data.deleteCall(c.id);
    }
  }
}

final historyBackupProvider = Provider<HistoryBackup>(
  (ref) => HistoryBackup(ref),
);
