import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/services/tasks_bridge.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';

/// Call back reminders (P25): ZT Phone reminds at the time, a task appears
/// in ZT Tasks, and both are done once I call the number.
class CallBacks {
  CallBacks(this.ref);
  final Ref ref;

  /// Sets a reminder to call [number] at [at]. Returns whether ZT Tasks got
  /// its task too (false when that failed; the reminder is set either way).
  Future<bool> add({
    required String number,
    required DateTime at,
    PhoneContact? contact,
  }) async {
    final String name = contact?.name ?? number;
    final String id = _newId();
    String? taskId;
    try {
      taskId = await ref
          .read(tasksBridgeProvider)
          .addCallBack(
            title: currentL10n.callBackTaskTitle(name),
            number: number,
            due: at,
            contactId: contact?.id,
          );
    } on Object {
      taskId = null;
    }
    await ref
        .read(phoneDataProvider)
        .saveCallBack(
          CallBack(
            id: id,
            number: number,
            name: contact?.name ?? '',
            at: at,
            createdAt: DateTime.now(),
            contactId: contact?.id,
            taskId: taskId,
          ),
        );
    await ref.read(telecomProvider).scheduleCallBack(id, number, at);
    return taskId != null;
  }

  /// Cancels the reminder and removes its task.
  Future<void> cancel(CallBack c) => _finish(c, deleteTask: true);

  Future<void> _finish(CallBack c, {required bool deleteTask}) async {
    await ref.read(telecomProvider).cancelCallBack(c.id);
    await ref.read(phoneDataProvider).deleteCallBack(c.id);
    final String? taskId = c.taskId;
    if (taskId != null) {
      try {
        await ref.read(tasksBridgeProvider).finish(taskId, delete: deleteTask);
      } on Object {
        // Offline or locked: the task stays; it can be ticked off in Tasks.
      }
    }
  }

  /// On every open: reminders whose number I've called since are done
  /// (the task is ticked off), and the rest are scheduled on this phone
  /// (one set on another phone, or after a reinstall).
  Future<void> refresh(List<CallLogEntry> log) async {
    final List<CallBack> pending = await ref
        .read(phoneDataProvider)
        .callBacks();
    for (final CallBack c in pending) {
      if (calledBack(c, log)) {
        await _finish(c, deleteTask: false);
      } else if (c.at.isAfter(DateTime.now())) {
        await ref.read(telecomProvider).scheduleCallBack(c.id, c.number, c.at);
      }
    }
  }

  /// Whether a call with [c]'s number connected after the reminder was set.
  static bool calledBack(CallBack c, List<CallLogEntry> log) => log.any(
    (CallLogEntry e) =>
        e.date.isAfter(c.createdAt) &&
        e.duration > Duration.zero &&
        (e.type == CallType.outgoing || e.type == CallType.incoming) &&
        PhoneNumbers.same(e.number, c.number),
  );

  static String _newId() {
    final Random r = Random.secure();
    return 'cb_${List<String>.generate(16, (_) => r.nextInt(16).toRadixString(16)).join()}';
  }
}

final callBacksServiceProvider = Provider<CallBacks>((ref) => CallBacks(ref));

/// The quick choices on the "Remind me to call back" sheet.
enum CallBackWhen { in15m, in1h, in3h, tonight, tomorrow }

/// When [w] is, from [now]. "Tonight" is 20:00 (tomorrow's if past 19:00);
/// "Tomorrow" is 09:00 tomorrow.
DateTime callBackTime(CallBackWhen w, DateTime now) => switch (w) {
  CallBackWhen.in15m => now.add(const Duration(minutes: 15)),
  CallBackWhen.in1h => now.add(const Duration(hours: 1)),
  CallBackWhen.in3h => now.add(const Duration(hours: 3)),
  CallBackWhen.tonight =>
    now.hour < 19
        ? DateTime(now.year, now.month, now.day, 20)
        : DateTime(now.year, now.month, now.day + 1, 20),
  CallBackWhen.tomorrow => DateTime(now.year, now.month, now.day + 1, 9),
};
