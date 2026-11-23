import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/calendar/meeting_guard.dart';
import 'package:zerotrust_phone/calendar/phone_calendar.dart';
import 'package:zerotrust_phone/calendar/recurrence.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/mirror_items.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';

/// Phone 0.8.0 froze with a full calendar and a long contact list: the
/// screen thread expanded the whole calendar once per contact, and read the
/// whole address book again on every change.
void main() {
  final DateTime now = DateTime(2026, 11, 23, 9);

  /// A calendar like one imported from Google: years of events, many of
  /// them repeating since long ago.
  List<PhoneEvent> bigCalendar(int count) => <PhoneEvent>[
    for (int i = 0; i < count; i++)
      () {
        final DateTime start = i % 5 == 0
            // A fifth of them in the coming week.
            ? now.add(Duration(hours: 1 + i % 160))
            : DateTime(2015 + i % 11, 1 + i % 12, 1 + i % 28, 8 + i % 10);
        return PhoneEvent(
          id: 'e$i',
          title: i % 3 == 0 ? 'Coffee with First$i Last$i' : 'Event $i',
          start: start,
          end: start.add(const Duration(hours: 1)),
          rrule: switch (i % 20) {
            1 => 'FREQ=WEEKLY;BYDAY=MO,WE',
            2 => 'FREQ=YEARLY',
            3 => 'FREQ=DAILY',
            4 => 'FREQ=MONTHLY;BYDAY=2TU',
            6 => 'FREQ=WEEKLY;INTERVAL=2;COUNT=400',
            _ => null,
          },
          contactIds: i % 7 == 0 ? <String>['c${i * 3}'] : const <String>[],
        );
      }(),
  ];

  List<PhoneContact> bigAddressBook(int count) => <PhoneContact>[
    for (int i = 0; i < count; i++)
      PhoneContact(
        id: 'c$i',
        // Some with one name only, which a title never matches.
        name: i % 9 == 0 ? 'Single$i' : 'First$i Last$i',
        phones: <String>['+97250${1000000 + i}'],
      ),
  ];

  group('meeting lines with a long contact list', () {
    setUpAll(() => initializeDateFormatting());

    test('the rules for 3,000 contacts and 800 events are quick', () {
      final List<PhoneEvent> events = bigCalendar(800);
      final List<PhoneContact> contacts = bigAddressBook(3000);
      final Stopwatch watch = Stopwatch()..start();
      final MeetingRules rules = MeetingRules.build(
        events: events,
        contacts: contacts,
        guard: const MeetingGuard(mode: InMeeting.silence),
        l10n: lookupAppL10n(const Locale('en')),
        locale: 'en',
        now: now,
      );
      watch.stop();
      expect(rules.hints, isNotEmpty);
      expect(rules.busy, isNotEmpty);
      // Before the fix this took about a second per contact (the best part
      // of an hour here). Now it is a fraction of a second; the limit is
      // loose so a slow test machine doesn't trip it.
      expect(watch.elapsed, lessThan(const Duration(seconds: 15)));
    });

    test('every contact gets the same line as when asked one by one', () {
      final List<PhoneEvent> events = bigCalendar(300);
      final List<PhoneContact> contacts = bigAddressBook(400);
      final AppL10n en = lookupAppL10n(const Locale('en'));
      final MeetingRules rules = MeetingRules.build(
        events: events,
        contacts: contacts,
        guard: const MeetingGuard(),
        l10n: en,
        locale: 'en',
        now: now,
      );
      // The slow way, as 0.8.0 did it.
      final List<Meeting> week = Meetings.between(
        events,
        now,
        now.add(const Duration(days: 7)),
      );
      final Map<String, String> expected = <String, String>{};
      for (final PhoneContact c in contacts) {
        for (final Meeting m in week) {
          if (!Meetings.isWith(m, c)) continue;
          expected[PhoneNumbers.lookupKey(c.phones.single)] = meetingLine(
            m,
            now,
            en,
            'en',
          );
          break;
        }
      }
      expect(expected, isNotEmpty);
      expect(rules.hints, expected);
      expect(
        Meetings.nextWith(events, contacts[3], now)?.title,
        MeetingFinder(week).nextWith(contacts[3])?.title,
      );
    });

    test('a linked meeting later in the week loses to a named one sooner', () {
      const PhoneContact dana = PhoneContact(
        id: 'd',
        name: 'Dana Levi',
        phones: <String>['054-123-4567'],
      );
      PhoneEvent event(
        String id,
        String title,
        DateTime start, {
        bool linked = false,
      }) => PhoneEvent(
        id: id,
        title: title,
        start: start,
        end: start.add(const Duration(hours: 1)),
        contactIds: linked ? <String>['d'] : const <String>[],
      );
      final List<PhoneEvent> events = <PhoneEvent>[
        event('late', 'Lunch', now.add(const Duration(days: 2)), linked: true),
        event('soon', 'Call DANA LEVI', now.add(const Duration(hours: 2))),
      ];
      expect(Meetings.nextWith(events, dana, now)?.title, 'Call DANA LEVI');
      expect(
        Meetings.nextWith(<PhoneEvent>[events.first], dana, now)?.title,
        'Lunch',
      );
    });
  });

  group('repeating events from years ago', () {
    test('starting near the window finds the same times as walking from '
        'the first one', () {
      const List<String> rules = <String>[
        'FREQ=DAILY',
        'FREQ=DAILY;INTERVAL=3',
        'FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR',
        'FREQ=WEEKLY',
        'FREQ=WEEKLY;BYDAY=SU,TU,TH;WKST=SU',
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR',
        'FREQ=WEEKLY;INTERVAL=5',
        'FREQ=MONTHLY',
        'FREQ=MONTHLY;BYMONTHDAY=31',
        'FREQ=MONTHLY;BYDAY=-1FR',
        'FREQ=MONTHLY;INTERVAL=3;BYDAY=2TU',
        'FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1',
        'FREQ=YEARLY',
        'FREQ=YEARLY;INTERVAL=4',
        'FREQ=YEARLY;BYMONTH=3,9;BYDAY=1SU',
        'FREQ=YEARLY;BYDAY=20MO',
        'FREQ=WEEKLY;COUNT=300',
        'FREQ=DAILY;UNTIL=20260115T000000Z',
        'FREQ=WEEKLY;UNTIL=20270101',
        'FREQ=MONTHLY;BYMONTHDAY=31;BYMONTH=2',
      ];
      final List<DateTime> starts = <DateTime>[
        DateTime(2012, 2, 29, 9),
        DateTime(2019, 12, 31, 23, 30),
        DateTime(2026, 11, 20, 7),
        DateTime(2026, 11, 25, 12),
        DateTime(2031, 1, 1, 10),
      ];
      final List<(DateTime, DateTime)> windows = <(DateTime, DateTime)>[
        (now, now.add(const Duration(days: 7))),
        (DateTime(2026, 3, 27, 1), DateTime(2026, 3, 30)),
        (DateTime(2026, 10, 24), DateTime(2026, 10, 26, 3)),
        (DateTime(2020), DateTime(2020, 1, 2)),
        (DateTime(2026, 12, 28), DateTime(2027, 1, 20)),
      ];
      int compared = 0;
      for (final String text in rules) {
        final RecurrenceRule rule = RecurrenceRule.tryParse(text)!;
        for (final DateTime start in starts) {
          for (final (DateTime from, DateTime to) in windows) {
            // Every occurrence from the very first, the slow way.
            final List<DateTime> slow = <DateTime>[];
            for (final DateTime t in rule.occurrences(start)) {
              if (!t.isBefore(to)) break;
              if (!t.isBefore(from)) slow.add(t);
            }
            expect(
              rule.between(start, from, to),
              slow,
              reason: '$text from $start in $from..$to',
            );
            compared += slow.length;
          }
        }
      }
      expect(compared, greaterThan(300));
    });

    test('a daily event since 1990 is found without walking 13,000 days', () {
      final RecurrenceRule rule = RecurrenceRule.tryParse('FREQ=DAILY')!;
      final Stopwatch watch = Stopwatch()..start();
      for (int i = 0; i < 2000; i++) {
        expect(
          rule.between(
            DateTime(1990, 1, 1, 8),
            now,
            now.add(const Duration(days: 2)),
          ),
          <DateTime>[DateTime(2026, 11, 24, 8), DateTime(2026, 11, 25, 8)],
        );
      }
      // 2,000 lookups walked 26 million days before, half a minute or more.
      expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
    });
  });

  group('a mirror re-reads only what changed', () {
    late Map<String, LocalItem> store;
    late StreamController<Set<String>> changes;
    late StreamController<void> refreshed;
    late int fullReads;
    late List<String> singleReads;

    LocalItem contact(String id, String name, {bool deleted = false}) =>
        LocalItem(
          itemId: id,
          updatedAt: DateTime.utc(2026, 11, 23),
          deleted: deleted,
          json: deleted
              ? null
              : <String, Object?>{
                  'kind': 'contact',
                  'displayName': name,
                  'phones': <String>['050-000-0000'],
                },
        );

    MirrorItems<PhoneContact> mirror() => MirrorItems<PhoneContact>(
      liveItems: () async {
        fullReads++;
        // Reading everything takes a moment.
        await Future<void>.delayed(Duration.zero);
        return <LocalItem>[
          for (final LocalItem i in store.values)
            if (!i.deleted) i,
        ];
      },
      get: (String id) async {
        singleReads.add(id);
        return store[id];
      },
      changes: changes.stream,
      refreshed: refreshed.stream,
      parse: PhoneContact.fromItem,
    );

    setUp(() {
      store = <String, LocalItem>{
        for (int i = 0; i < 500; i++) 'c$i': contact('c$i', 'Name $i'),
      };
      changes = StreamController<Set<String>>.broadcast();
      refreshed = StreamController<void>.broadcast();
      fullReads = 0;
      singleReads = <String>[];
    });

    tearDown(() async {
      await changes.close();
      await refreshed.close();
    });

    test('a change, a delete and a new contact cost one read each', () async {
      final List<List<PhoneContact>> seen = <List<PhoneContact>>[];
      final StreamSubscription<List<PhoneContact>> sub = mirror()
          .watch()
          .listen(seen.add);
      await pumpEventQueue();
      expect(seen.single, hasLength(500));
      expect(fullReads, 1);

      store['c7'] = contact('c7', 'Renamed');
      changes.add(<String>{'c7'});
      await pumpEventQueue();
      expect(seen.last, hasLength(500));
      expect(
        seen.last.singleWhere((PhoneContact c) => c.id == 'c7').name,
        'Renamed',
      );

      store['c8'] = contact('c8', '', deleted: true);
      store['new'] = contact('new', 'Brand New');
      changes.add(<String>{'c8', 'new'});
      await pumpEventQueue();
      expect(seen.last, hasLength(500));
      expect(seen.last.any((PhoneContact c) => c.id == 'c8'), isFalse);
      expect(seen.last.any((PhoneContact c) => c.name == 'Brand New'), isTrue);

      // The whole address book was read once; after that only three items.
      expect(fullReads, 1);
      expect(singleReads, unorderedEquals(<String>['c7', 'c8', 'new']));
      await sub.cancel();
    });

    test('changes that pile up are taken together', () async {
      final List<List<PhoneContact>> seen = <List<PhoneContact>>[];
      final StreamSubscription<List<PhoneContact>> sub = mirror()
          .watch()
          .listen(seen.add);
      // Written while the first read is still under way: not lost.
      for (int i = 0; i < 100; i++) {
        store['c$i'] = contact('c$i', 'Changed $i');
        changes.add(<String>{'c$i'});
      }
      await pumpEventQueue();
      expect(
        seen.last.where((PhoneContact c) => c.name.startsWith('Changed')),
        hasLength(100),
      );
      // One list for the first read and one for the hundred changes that
      // came during it, not a hundred and one.
      expect(seen, hasLength(2));
      expect(fullReads, 1);
      expect(singleReads, hasLength(100));
      await sub.cancel();
    });

    test('everything is read again after a sync', () async {
      final List<List<PhoneContact>> seen = <List<PhoneContact>>[];
      final StreamSubscription<List<PhoneContact>> sub = mirror()
          .watch()
          .listen(seen.add);
      await pumpEventQueue();
      // A change nobody announced.
      store.remove('c1');
      refreshed.add(null);
      await pumpEventQueue();
      expect(fullReads, 2);
      expect(seen.last, hasLength(499));
      await sub.cancel();
      // Nothing more is read once nobody listens.
      changes.add(<String>{'c2'});
      refreshed.add(null);
      await pumpEventQueue();
      expect(fullReads, 2);
      expect(singleReads, isEmpty);
    });

    test('contacts come sorted by name, capitals aside', () {
      PhoneContact named(String name) =>
          PhoneContact(id: name, name: name, phones: const <String>['1']);
      expect(
        ContactsMirror.byName(<PhoneContact>[
          named('dana'),
          named('Avi'),
          named('Carmel'),
          named('beni'),
        ]).map((PhoneContact c) => c.name),
        <String>['Avi', 'beni', 'Carmel', 'dana'],
      );
    });
  });
}
