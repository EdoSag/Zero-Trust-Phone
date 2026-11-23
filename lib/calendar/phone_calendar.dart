import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/calendar/recurrence.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/mirror_items.dart';

/// The ZT Calendar app id, whose items hold the events (P26).
const String calendarAppId = 'calendar';

/// The Calendar app key of the unlocked account, derived at unlock like the
/// Contacts key and zeroed when the vault locks. Phone only reads with it.
final calendarKeyProvider = NotifierProvider<CalendarKey, Uint8List?>(
  CalendarKey.new,
);

class CalendarKey extends Notifier<Uint8List?> {
  @override
  Uint8List? build() {
    ref.listen(vaultControllerProvider, (_, VaultState next) {
      if (next is VaultLocked) clear();
    });
    ref.onDispose(_zero);
    return null;
  }

  Future<void> deriveFrom(Uint8List dek) async {
    final Uint8List key = await KeyHierarchy.appKey(dek, calendarAppId);
    _zero();
    state = key;
  }

  void clear() {
    _zero();
    state = null;
  }

  void _zero() {
    final Uint8List? key = state;
    key?.fillRange(0, key.length, 0);
  }
}

/// What Phone needs of a ZT Calendar event (Calendar's
/// `CalendarEvent.toJson`). Tolerant of fields newer versions add.
@immutable
class PhoneEvent {
  const PhoneEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.rrule,
    this.exceptions = const <DateTime>{},
    this.seriesId,
    this.originalStart,
    this.contactIds = const <String>[],
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String? rrule;
  final Set<DateTime> exceptions;

  /// A changed occurrence of a repeating event: the series and the start
  /// it replaces.
  final String? seriesId;
  final DateTime? originalStart;
  final List<String> contactIds;

  Duration get length => end.difference(start);

  /// An event item's JSON, or null for calendars, feeds and other kinds.
  static PhoneEvent? fromItem(String id, Map<String, Object?>? json) {
    if (json == null) return null;
    // Calendar keeps calendars and feeds as items too, with a `kind`;
    // events are the items with a start.
    if (json['kind'] != null && json['kind'] != 'event') return null;
    final DateTime? start = _date(json['start']);
    if (start == null) return null;
    final bool allDay = json['allDay'] == true;
    DateTime? end = _date(json['end']);
    if (end == null || end.isBefore(start)) {
      end = allDay
          ? DateTime(start.year, start.month, start.day + 1)
          : start.add(const Duration(hours: 1));
    }
    List<String> strings(Object? v) => <String>[
      if (v is List<Object?>)
        for (final Object? e in v)
          if (e is String) e,
    ];
    return PhoneEvent(
      id: id,
      title: (json['title'] as String?)?.trim() ?? '',
      start: start,
      end: end,
      allDay: allDay,
      rrule: json['rrule'] as String?,
      exceptions: <DateTime>{
        for (final String s in strings(json['exdates'])) ?_date(s),
      },
      seriesId: json['seriesId'] as String?,
      originalStart: _date(json['originalStart']),
      contactIds: strings(json['contactIds']),
    );
  }

  /// Calendar writes all-day dates as `yyyy-mm-dd` and times in UTC.
  static DateTime? _date(Object? v) {
    if (v is! String) return null;
    final RegExpMatch? m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    return DateTime.tryParse(v)?.toLocal();
  }
}

/// One occurrence of an event, repeating ones expanded.
@immutable
class Meeting {
  const Meeting({required this.event, required this.start, required this.end});

  final PhoneEvent event;
  final DateTime start;
  final DateTime end;

  String get title => event.title;
  bool get allDay => event.allDay;
}

abstract final class Meetings {
  /// Every occurrence that overlaps `[from, to)`, by start time.
  static List<Meeting> between(
    List<PhoneEvent> events,
    DateTime from,
    DateTime to,
  ) {
    // Changed occurrences replace the series' own at their original start.
    final Map<String, Set<DateTime>> moved = <String, Set<DateTime>>{};
    for (final PhoneEvent e in events) {
      final String? series = e.seriesId;
      final DateTime? original = e.originalStart;
      if (series != null && original != null) {
        (moved[series] ??= <DateTime>{}).add(original);
      }
    }
    final List<Meeting> out = <Meeting>[];
    for (final PhoneEvent e in events) {
      final RecurrenceRule? rule = e.seriesId == null
          ? RecurrenceRule.tryParse(e.rrule)
          : null;
      if (rule == null) {
        if (e.end.isAfter(from) && e.start.isBefore(to)) {
          out.add(Meeting(event: e, start: e.start, end: e.end));
        }
        continue;
      }
      final Duration length = e.length;
      for (final DateTime s in rule.between(
        e.start,
        from.subtract(length),
        to,
        exclude: <DateTime>{...e.exceptions, ...?moved[e.id]},
        limit: 200,
      )) {
        final DateTime end = s.add(length);
        if (end.isAfter(from)) out.add(Meeting(event: e, start: s, end: end));
      }
    }
    out.sort((Meeting a, Meeting b) => a.start.compareTo(b.start));
    return out;
  }

  /// Whether [m] is with [contact]: the contact is linked to the event in
  /// ZT Calendar, or the title names them in full ("Lunch with Dana Levi").
  static bool isWith(Meeting m, PhoneContact contact) {
    if (m.event.contactIds.contains(contact.id)) return true;
    final String name = contact.name.trim().toLowerCase();
    if (name.split(RegExp(r'\s+')).length < 2) return false;
    return m.title.toLowerCase().contains(name);
  }

  /// How far ahead Phone looks for meetings.
  static const Duration week = Duration(days: 7);

  /// The next meeting with [contact] that hasn't ended, within [ahead].
  ///
  /// For one contact. For the whole address book expand the calendar once
  /// with [between] and ask a [MeetingFinder]: expanding it again for every
  /// contact froze the app with a full calendar and a long contact list.
  static Meeting? nextWith(
    List<PhoneEvent> events,
    PhoneContact contact,
    DateTime now, {
    Duration ahead = week,
  }) => MeetingFinder(between(events, now, now.add(ahead))).nextWith(contact);

  /// Times I'm in a timed meeting in `[now, now + ahead)`, overlapping
  /// ones joined. All-day events (holidays, trips) don't count.
  static List<(DateTime, DateTime)> busy(
    List<PhoneEvent> events,
    DateTime now, {
    Duration ahead = week,
  }) => busyIn(between(events, now, now.add(ahead)));

  /// [busy] for meetings already expanded with [between].
  static List<(DateTime, DateTime)> busyIn(List<Meeting> meetings) {
    final List<(DateTime, DateTime)> out = <(DateTime, DateTime)>[];
    for (final Meeting m in meetings) {
      if (m.allDay || !m.end.isAfter(m.start)) continue;
      if (out.isNotEmpty && !m.start.isAfter(out.last.$2)) {
        final (DateTime s, DateTime e) = out.removeLast();
        out.add((s, m.end.isAfter(e) ? m.end : e));
      } else {
        out.add((m.start, m.end));
      }
    }
    return out;
  }
}

/// Finds each contact's next meeting among meetings already expanded with
/// [Meetings.between] (sorted by start), without expanding the calendar
/// again per contact. Answers the same as [Meetings.isWith] would.
class MeetingFinder {
  MeetingFinder(this.meetings)
    : _titles = <String>[
        for (final Meeting m in meetings) m.title.toLowerCase(),
      ] {
    for (int i = 0; i < meetings.length; i++) {
      for (final String id in meetings[i].event.contactIds) {
        _linked.putIfAbsent(id, () => i);
      }
    }
  }

  final List<Meeting> meetings;
  final List<String> _titles;

  /// Contact id to the first meeting it is linked to in ZT Calendar.
  final Map<String, int> _linked = <String, int>{};

  static final RegExp _space = RegExp(r'\s');

  /// The first meeting with [contact], or null.
  Meeting? nextWith(PhoneContact contact) {
    if (meetings.isEmpty) return null;
    int? first = _linked[contact.id];
    // A title only counts when it names the contact in full: "Lunch with
    // Dana Levi", not every "Dana".
    final String name = contact.name.trim().toLowerCase();
    if (_space.hasMatch(name)) {
      final int end = first ?? meetings.length;
      for (int i = 0; i < end; i++) {
        if (_titles[i].contains(name)) {
          first = i;
          break;
        }
      }
    }
    return first == null ? null : meetings[first];
  }
}

/// Phone's own encrypted copy of the calendar: a local store opened with
/// the Calendar key, kept up to date from the account's Calendar items.
/// Read only; deleting it loses nothing.
final calendarMirrorProvider = FutureProvider<CalendarMirror>((ref) async {
  final Uint8List? unlocked = ref.watch(calendarKeyProvider);
  if (unlocked == null) throw const VaultIsLocked();
  final Uint8List key = Uint8List.fromList(unlocked);
  bool disposed = false;
  ref.onDispose(() {
    disposed = true;
    key.fillRange(0, key.length, 0);
  });
  final String? userId = ref.watch(accountServiceProvider).currentUserId;
  if (userId == null) throw StateError('Not signed in');
  final String path = await ZtLocalStore.pathFor(
    appId: 'phone_calendar',
    userId: userId,
  );
  ZtLocalStore store;
  try {
    store = await ZtLocalStore.open(appKey: key, path: path);
  } on LocalStoreUnreadable {
    await ZtLocalStore.moveAside(path);
    store = await ZtLocalStore.open(appKey: key, path: path);
  }
  final String deviceId = await ref.watch(ztDeviceIdProvider.future);
  final ItemSyncEngine engine = await ItemSyncEngine.fromVault(
    appId: calendarAppId,
    appKey: key,
    deviceId: deviceId,
    store: store,
    backend: ReadOnlySyncBackend(ref.watch(ztSyncBackendProvider)),
  );
  final CalendarMirror mirror = CalendarMirror(store: store, engine: engine);
  if (disposed) {
    await mirror.close();
    throw const VaultIsLocked();
  }
  ref.onDispose(mirror.close);
  mirror.start();
  return mirror;
});

class CalendarMirror {
  CalendarMirror({required this.store, required this.engine});

  final ZtLocalStore store;
  final ItemSyncEngine engine;
  AppLifecycleListener? _lifecycle;
  final StreamController<void> _refreshed = StreamController<void>.broadcast();

  void start() {
    refresh().ignore();
    engine.startLive();
    _lifecycle = AppLifecycleListener(onResume: () => refresh().ignore());
  }

  Future<void> refresh() async {
    try {
      await engine.sync();
    } on Object {
      // Offline: the events already on this device still work.
    }
    if (!_refreshed.isClosed) _refreshed.add(null);
  }

  Future<List<PhoneEvent>> events() async => <PhoneEvent>[
    for (final LocalItem item in await store.liveItems())
      ?PhoneEvent.fromItem(item.itemId, item.json),
  ];

  /// The events now, then after every change. Only the events that
  /// changed are read again (see [MirrorItems]).
  Stream<List<PhoneEvent>> watch() => MirrorItems<PhoneEvent>.of(
    store,
    refreshed: _refreshed.stream,
    parse: PhoneEvent.fromItem,
  ).watch();

  Future<void> close() async {
    _lifecycle?.dispose();
    await _refreshed.close();
    await engine.close();
    await store.close();
  }
}

/// The calendar's events (series unexpanded). Empty while locked, before
/// the first pull, or when ZT Calendar isn't used.
final phoneEventsProvider = StreamProvider<List<PhoneEvent>>((ref) async* {
  final CalendarMirror mirror = await ref.watch(calendarMirrorProvider.future);
  yield* mirror.watch();
});
