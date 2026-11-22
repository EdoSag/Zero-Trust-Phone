import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/app/phone_config.dart';
import 'package:zerotrust_phone/calendar/meeting_guard.dart';
import 'package:zerotrust_phone/calendar/phone_calendar.dart';
import 'package:zerotrust_phone/call/call_state.dart';
import 'package:zerotrust_phone/call/call_tools.dart';
import 'package:zerotrust_phone/call/in_call_app.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/services/notes_bridge.dart';

/// P26 calendar awareness and P27 in-call tools.
PhoneEvent event(
  String id,
  String title,
  DateTime start, {
  Duration length = const Duration(hours: 1),
  bool allDay = false,
  String? rrule,
  List<String> contactIds = const <String>[],
  List<String> exdates = const <String>[],
  String? seriesId,
  DateTime? originalStart,
}) => PhoneEvent.fromItem(id, <String, Object?>{
  'kind': 'event',
  'title': title,
  'start': allDay
      ? '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}'
      : start.toUtc().toIso8601String(),
  'end': allDay ? null : start.add(length).toUtc().toIso8601String(),
  'allDay': allDay,
  'rrule': rrule,
  'exdates': exdates,
  'contactIds': contactIds,
  'seriesId': seriesId,
  'originalStart': originalStart?.toUtc().toIso8601String(),
})!;

const PhoneContact dana = PhoneContact(
  id: 'contact-dana',
  name: 'Dana Levi',
  phones: <String>['+972 54-123-4567'],
);
const PhoneContact noa = PhoneContact(
  id: 'contact-noa',
  name: 'Noa',
  phones: <String>['050-7654321'],
);

class FakeCallControl extends CallControl {
  @override
  Stream<(String, String)> get rttText =>
      const Stream<(String, String)>.empty();
}

class FakeCallTools extends CallTools {
  final List<String> done = <String>[];
  @override
  Future<bool> openCalendar() async {
    done.add('calendar');
    return true;
  }

  @override
  Future<bool> text(String number, String text) async {
    done.add('text $number $text');
    return true;
  }
}

void main() {
  // The app has them from Flutter's localizations; plain tests load them.
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('he');
  });

  // Monday 2026-11-23 09:00 local.
  final DateTime now = DateTime(2026, 11, 23, 9);

  group('P26 events', () {
    test('calendars and feeds are not events', () {
      expect(
        PhoneEvent.fromItem('c', <String, Object?>{
          'kind': 'calendar',
          'name': 'Work',
        }),
        isNull,
      );
    });

    test('a weekly meeting repeats, skips its exdate and a moved one', () {
      final DateTime first = DateTime(2026, 11, 2, 10);
      final List<PhoneEvent> events = <PhoneEvent>[
        event(
          's',
          'Standup',
          first,
          rrule: 'FREQ=WEEKLY',
          exdates: <String>[
            DateTime(2026, 11, 30, 10).toUtc().toIso8601String(),
          ],
        ),
        // The 7 Dec one moved to 11:00.
        event(
          'm',
          'Standup (moved)',
          DateTime(2026, 12, 7, 11),
          seriesId: 's',
          originalStart: DateTime(2026, 12, 7, 10),
        ),
      ];
      final List<Meeting> got = Meetings.between(
        events,
        now,
        DateTime(2026, 12, 10),
      );
      expect(
        got.map((Meeting m) => (m.start, m.title)).toList(),
        <(DateTime, String)>[
          (DateTime(2026, 11, 23, 10), 'Standup'),
          (DateTime(2026, 12, 7, 11), 'Standup (moved)'),
        ],
      );
    });

    test('a meeting is with a contact when linked, or named in full', () {
      final List<PhoneEvent> events = <PhoneEvent>[
        event(
          'a',
          'Lunch',
          now.add(const Duration(days: 1)),
          contactIds: <String>['contact-noa'],
        ),
        event('b', 'Review with Dana Levi', now.add(const Duration(hours: 3))),
        // A single first name in a title is too loose to count.
        event('c', 'Noa birthday drinks', now.add(const Duration(hours: 1))),
      ];
      expect(
        Meetings.nextWith(events, dana, now)?.title,
        'Review with Dana Levi',
      );
      expect(Meetings.nextWith(events, noa, now)?.title, 'Lunch');
    });

    test('busy times join overlaps and leave out all-day events', () {
      final List<PhoneEvent> events = <PhoneEvent>[
        event('a', 'A', DateTime(2026, 11, 23, 10)),
        event('b', 'B', DateTime(2026, 11, 23, 10, 30)),
        event('c', 'C', DateTime(2026, 11, 23, 14)),
        event('d', 'Holiday', DateTime(2026, 11, 24), allDay: true),
      ];
      expect(Meetings.busy(events, now), <(DateTime, DateTime)>[
        (DateTime(2026, 11, 23, 10), DateTime(2026, 11, 23, 11, 30)),
        (DateTime(2026, 11, 23, 14), DateTime(2026, 11, 23, 15)),
      ]);
    });

    test('meeting lines in English and Hebrew', () {
      final AppL10n en = lookupAppL10n(const Locale('en'));
      final AppL10n he = lookupAppL10n(const Locale('he'));
      Meeting at(DateTime s) => Meeting(
        event: event('x', 'Design review', s),
        start: s,
        end: s.add(const Duration(hours: 1)),
      );
      expect(meetingLine(at(now), now, en, 'en'), 'Now: Design review');
      expect(
        meetingLine(at(DateTime(2026, 11, 23, 15)), now, en, 'en'),
        'Today 15:00: Design review',
      );
      expect(
        meetingLine(at(DateTime(2026, 11, 24, 10)), now, en, 'en'),
        'Tomorrow 10:00: Design review',
      );
      expect(
        meetingLine(at(DateTime(2026, 11, 26, 10)), now, en, 'en'),
        'Thu 10:00: Design review',
      );
      expect(
        meetingLine(at(DateTime(2026, 11, 24, 10)), now, he, 'he'),
        'מחר 10:00: Design review',
      );
    });

    test('rules: lines per number, busy times only when not "ring"', () {
      final AppL10n en = lookupAppL10n(const Locale('en'));
      final List<PhoneEvent> events = <PhoneEvent>[
        event('b', 'Review with Dana Levi', DateTime(2026, 11, 24, 10)),
      ];
      final MeetingRules ring = MeetingRules.build(
        events: events,
        contacts: const <PhoneContact>[dana, noa],
        guard: const MeetingGuard(),
        l10n: en,
        locale: 'en',
        now: now,
      );
      expect(ring.hints, <String, String>{
        '541234567': 'Tomorrow 10:00: Review with Dana Levi',
      });
      expect(ring.busy, isEmpty);
      final MeetingRules decline = MeetingRules.build(
        events: events,
        contacts: const <PhoneContact>[dana],
        guard: const MeetingGuard(mode: InMeeting.decline, showMeetings: false),
        l10n: en,
        locale: 'en',
        now: now,
      );
      expect(decline.hints, isEmpty);
      expect(decline.busy, hasLength(1));
      expect(decline.message, en.inMeetingDefaultMessage);
      expect(decline.same(ring), isFalse);
    });

    test('settings round trip', () {
      const MeetingGuard g = MeetingGuard(
        mode: InMeeting.silence,
        message: 'Busy',
        letRepeatCallersRing: false,
        showMeetings: false,
      );
      expect(MeetingGuard.fromJson(g.toJson()).toJson(), g.toJson());
      expect(
        MeetingGuard.fromJson(<String, Object?>{'mode': 'nope'}).mode,
        InMeeting.ring,
      );
    });
  });

  group('P27 call notes', () {
    test(
      'notes wait on the phone and move into ZT Notes; failures stay',
      () async {
        final InMemoryPreferencesStore prefs = InMemoryPreferencesStore();
        final PendingCallNotes pending = PendingCallNotes(prefs);
        await pending.add(
          PendingCallNote(
            number: '0541234567',
            name: 'Dana',
            at: now,
            text: 'Send the contract',
          ),
        );
        await pending.add(
          PendingCallNote(number: '050', name: '', at: now, text: 'fails'),
        );
        final List<String> saved = <String>[];
        final int moved = await pending.moveInto((PendingCallNote n) async {
          if (n.text == 'fails') throw StateError('offline');
          saved.add(n.text);
        });
        expect(moved, 1);
        expect(saved, <String>['Send the contract']);
        expect((await pending.all()).single.text, 'fails');
      },
    );

    test('a new note has the shape ZT Notes writes', () {
      final Map<String, Object?> j = newNoteJson(
        title: 'Call with Dana',
        body: 'x',
        now: now,
      );
      expect(j.keys.toSet(), <String>{
        'title',
        'body',
        'notebookId',
        'tagIds',
        'createdAt',
      });
      expect(j.containsKey('kind'), isFalse);
    });
  });

  group('call screen', () {
    late StreamController<CallsSnapshot> calls;
    late InMemoryPreferencesStore prefs;
    late FakeCallTools tools;

    Future<void> pump(WidgetTester tester, {String? card}) async {
      calls = StreamController<CallsSnapshot>();
      prefs = InMemoryPreferencesStore();
      if (card != null) prefs.values[MyCard.key] = card;
      tools = FakeCallTools();
      await tester.binding.setSurfaceSize(const Size(400, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            ztAppConfigProvider.overrideWithValue(phoneAppConfig),
            ztPreferencesStoreProvider.overrideWithValue(prefs),
            callControlProvider.overrideWithValue(FakeCallControl()),
            callToolsProvider.overrideWithValue(tools),
            callsProvider.overrideWith((ref) => calls.stream),
          ],
          child: MaterialApp(
            supportedLocales: ZtLanguages.supported,
            localizationsDelegates: const <LocalizationsDelegate<Object>>[
              AppL10n.delegate,
              ...ZtLanguages.delegates,
            ],
            home: const InCallScreen(),
          ),
        ),
      );
      await tester.pump();
      calls.add(
        CallsSnapshot.fromMap(<Object?, Object?>{
          'calls': <Object?>[
            <Object?, Object?>{
              'id': 'c1',
              'number': '0541234567',
              'name': 'Dana Levi',
              'state': 'active',
              'connectedAt': DateTime.now().millisecondsSinceEpoch,
              'meeting': 'Tomorrow 10:00: Design review',
            },
          ],
        }),
      );
      await tester.pump();
    }

    testWidgets('the next meeting shows under the call status', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      final Rect meeting = tester.getRect(
        find.byKey(const ValueKey<String>('call-meeting')),
      );
      expect(find.text('Tomorrow 10:00: Design review'), findsOneWidget);
      expect(
        meeting.top,
        greaterThanOrEqualTo(tester.getRect(find.text('00:00')).bottom),
      );
      expect(
        meeting.bottom,
        lessThan(tester.getRect(find.bySemanticsLabel('Mute')).top),
      );
    });

    testWidgets('More > Write a note keeps the note for ZT Notes', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('tool-note')));
      await tester.pumpAndSettle();
      expect(find.text('Call with Dana Levi'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('note-text')),
        'Send the contract',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final List<PendingCallNote> notes = await PendingCallNotes(prefs).all();
      expect(notes.single.text, 'Send the contract');
      expect(notes.single.number, '0541234567');
      expect(find.textContaining('moves to ZT Notes'), findsOneWidget);
    });

    testWidgets('Text my card is off until a card is set, then sends it', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey<String>('tool-card')))
            .enabled,
        isFalse,
      );
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      await pump(tester, card: 'Edo\n050-0000000');
      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('tool-card')));
      await tester.pumpAndSettle();
      expect(tools.done, <String>['text 0541234567 Edo\n050-0000000']);
    });

    testWidgets('More > Open ZT Calendar', (WidgetTester tester) async {
      await pump(tester);
      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('tool-calendar')));
      await tester.pumpAndSettle();
      expect(tools.done, <String>['calendar']);
    });
  });
}
