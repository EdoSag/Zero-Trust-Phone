import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/calendar/phone_calendar.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';

/// What happens to a call that comes in during a meeting in ZT Calendar
/// (P26).
enum InMeeting { ring, silence, decline }

/// Calendar awareness settings (P26). Kept on this phone: the call screen
/// and the Android side use them while the app is locked.
class MeetingGuard {
  const MeetingGuard({
    this.mode = InMeeting.ring,
    this.message,
    this.letRepeatCallersRing = true,
    this.showMeetings = true,
  });

  final InMeeting mode;

  /// The text sent when declining; null = the default in the app's
  /// language.
  final String? message;

  /// A second call from the same number within 15 minutes rings anyway, as
  /// in Android's Do Not Disturb, in case it's urgent.
  final bool letRepeatCallersRing;

  /// "Meeting tomorrow 10:00" on contacts and on the call screen.
  final bool showMeetings;

  String messageIn(AppL10n l) {
    final String? m = message?.trim();
    return m == null || m.isEmpty ? l.inMeetingDefaultMessage : m;
  }

  MeetingGuard copyWith({
    InMeeting? mode,
    String? Function()? message,
    bool? letRepeatCallersRing,
    bool? showMeetings,
  }) => MeetingGuard(
    mode: mode ?? this.mode,
    message: message != null ? message() : this.message,
    letRepeatCallersRing: letRepeatCallersRing ?? this.letRepeatCallersRing,
    showMeetings: showMeetings ?? this.showMeetings,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'mode': mode.name,
    'message': message,
    'repeat': letRepeatCallersRing,
    'show': showMeetings,
  };

  static MeetingGuard fromJson(Map<String, Object?> j) => MeetingGuard(
    mode: InMeeting.values.firstWhere(
      (InMeeting m) => m.name == j['mode'],
      orElse: () => InMeeting.ring,
    ),
    message: j['message'] as String?,
    letRepeatCallersRing: j['repeat'] != false,
    showMeetings: j['show'] != false,
  );
}

final meetingGuardProvider =
    NotifierProvider<MeetingGuardNotifier, MeetingGuard>(
      MeetingGuardNotifier.new,
    );

class MeetingGuardNotifier extends Notifier<MeetingGuard> {
  static const String _key = 'meeting_guard';
  late Future<void> loaded;

  @override
  MeetingGuard build() {
    loaded = _load();
    return const MeetingGuard();
  }

  Future<void> _load() async {
    try {
      final String? raw = await ref.read(ztPreferencesStoreProvider).read(_key);
      if (raw != null) {
        state = MeetingGuard.fromJson(
          (jsonDecode(raw) as Map<Object?, Object?>).cast<String, Object?>(),
        );
      }
    } on Object {
      // A damaged value falls back to the defaults.
    }
  }

  Future<void> set(MeetingGuard value) async {
    await loaded;
    state = value;
    await ref
        .read(ztPreferencesStoreProvider)
        .write(_key, jsonEncode(value.toJson()));
  }
}

/// What the Android side gets: when I'm busy (start and end times only,
/// kept sealed on the phone) and, in memory only, a line per contact
/// number about the next meeting with them for the call screen.
class MeetingRules {
  const MeetingRules({
    required this.mode,
    required this.message,
    required this.letRepeatCallersRing,
    required this.busy,
    required this.hints,
  });

  factory MeetingRules.build({
    required List<PhoneEvent> events,
    required List<PhoneContact> contacts,
    required MeetingGuard guard,
    required AppL10n l10n,
    required String locale,
    required DateTime now,
  }) {
    final Map<String, String> hints = <String, String>{};
    if (guard.showMeetings) {
      for (final PhoneContact c in contacts) {
        final Meeting? m = Meetings.nextWith(events, c, now);
        if (m == null) continue;
        final String line = meetingLine(m, now, l10n, locale);
        for (final String p in c.phones) {
          final String key = PhoneNumbers.lookupKey(p);
          if (key.isNotEmpty) hints[key] = line;
        }
      }
    }
    return MeetingRules(
      mode: guard.mode,
      message: guard.messageIn(l10n),
      letRepeatCallersRing: guard.letRepeatCallersRing,
      busy: guard.mode == InMeeting.ring
          ? const <(DateTime, DateTime)>[]
          : Meetings.busy(events, now),
      hints: hints,
    );
  }

  final InMeeting mode;
  final String message;
  final bool letRepeatCallersRing;
  final List<(DateTime, DateTime)> busy;
  final Map<String, String> hints;

  bool same(MeetingRules? o) =>
      o != null &&
      o.mode == mode &&
      o.message == message &&
      o.letRepeatCallersRing == letRepeatCallersRing &&
      _sameList(o.busy, busy) &&
      _sameMap(o.hints, hints);

  static bool _sameList(
    List<(DateTime, DateTime)> a,
    List<(DateTime, DateTime)> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameMap(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length &&
      a.entries.every((MapEntry<String, String> e) => b[e.key] == e.value);
}

/// "Now: Design review", "Today 15:00: Lunch", "Tomorrow 10:00: Review",
/// "Thu 10:00: Review", for the call screen and the number sheet.
String meetingLine(Meeting m, DateTime now, AppL10n l, String locale) {
  final String title = m.title.isEmpty ? l.meetingUntitled : m.title;
  if (!m.start.isAfter(now)) return l.meetingNow(title);
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime day = DateTime(m.start.year, m.start.month, m.start.day);
  final int days = day.difference(today).inDays;
  final String time = m.allDay ? '' : DateFormat.Hm(locale).format(m.start);
  final String when = switch (days) {
    0 => l.meetingToday(time),
    1 => l.meetingTomorrow(time),
    _ => '${DateFormat.E(locale).format(m.start)} $time',
  }.trim();
  return l.meetingAt(when, title);
}
