import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/call_stats_page.dart';
import 'package:zerotrust_phone/pages/recents_page.dart';
import 'package:zerotrust_phone/services/call_backs.dart';
import 'package:zerotrust_phone/services/private_calls.dart';
import 'package:zerotrust_phone/services/screening_sync.dart';
import 'package:zerotrust_phone/services/tasks_bridge.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/call_stats.dart';

CallLogEntry call(
  String number,
  CallType type,
  DateTime date, {
  int seconds = 0,
  int id = 1,
}) => CallLogEntry(
  id: id,
  number: number,
  type: type,
  date: date,
  duration: Duration(seconds: seconds),
);

/// Call stats (P28), call back reminders (P25) and the private call log
/// (P23).
void main() {
  // Friday 13 Nov 2026, 22:00.
  final DateTime now = DateTime(2026, 11, 13, 22);
  const PhoneContact dana = PhoneContact(
    id: 'dana',
    name: 'Dana Cohen',
    phones: <String>['+972541234567'],
  );
  const PhoneContact avi = PhoneContact(
    id: 'avi',
    name: 'Avi',
    phones: <String>['0527654321'],
  );
  final ContactDirectory directory = ContactDirectory(const <PhoneContact>[
    dana,
    avi,
  ]);
  final List<CallLogEntry> log = <CallLogEntry>[
    call(
      '0541234567',
      CallType.outgoing,
      DateTime(2026, 11, 13, 9),
      seconds: 600,
    ),
    call(
      '0527654321',
      CallType.incoming,
      DateTime(2026, 11, 12, 9),
      seconds: 120,
    ),
    call('0527654321', CallType.missed, DateTime(2026, 11, 11, 9)),
    call(
      '+972541234567',
      CallType.incoming,
      DateTime(2026, 11, 8, 9),
      seconds: 60,
    ),
    // Last month: only in the 30-day and longer views.
    call(
      '0527654321',
      CallType.outgoing,
      DateTime(2026, 10, 1, 9),
      seconds: 3600,
    ),
  ];

  group('stats', () {
    test('totals for the last 7 days', () {
      final CallStats s = CallStats.compute(
        log,
        now: now,
        period: StatsPeriod.week,
        directory: directory,
      );
      expect(s.calls, 4);
      expect(s.incoming, 2);
      expect(s.outgoing, 1);
      expect(s.missed, 1);
      expect(s.talk, const Duration(minutes: 13));
      expect(s.averageCall, const Duration(seconds: 260));
      // Two spellings of Dana's number are one person.
      expect(s.people.first.contact?.name, 'Dana Cohen');
      expect(s.people.first.calls, 2);
      expect(s.people[1].contact?.name, 'Avi');
      expect(s.people[1].missed, 1);
    });

    test('a longer period counts older calls, and reorders people', () {
      final CallStats s = CallStats.compute(
        log,
        now: now,
        period: StatsPeriod.year,
        directory: directory,
      );
      expect(s.calls, 5);
      expect(s.people.first.contact?.name, 'Avi');
    });

    test('weeks start on Sunday in Israel', () {
      final CallStats s = CallStats.compute(
        log,
        now: now,
        period: StatsPeriod.all,
        firstDayOfWeek: DateTime.sunday,
      );
      expect(s.weeks.length, 8);
      expect(s.weeks.last.start, DateTime(2026, 11, 8));
      expect(s.weeks.last.calls, 4);
      expect(s.weeks.last.talk, const Duration(minutes: 13));
      expect(s.weeks[s.weeks.length - 7].calls, 1); // Week of 27 Sep.
    });
  });

  group('call back', () {
    test('the quick times', () {
      expect(callBackTime(CallBackWhen.in1h, now), DateTime(2026, 11, 13, 23));
      // Past 19:00, "tonight" is tomorrow's evening.
      expect(
        callBackTime(CallBackWhen.tonight, now),
        DateTime(2026, 11, 14, 20),
      );
      expect(
        callBackTime(CallBackWhen.tonight, DateTime(2026, 11, 13, 10)),
        DateTime(2026, 11, 13, 20),
      );
      expect(
        callBackTime(CallBackWhen.tomorrow, now),
        DateTime(2026, 11, 14, 9),
      );
    });

    test('done once a call with them connects', () {
      final CallBack c = CallBack(
        id: 'cb',
        number: '+972 54-123-4567',
        name: 'Dana Cohen',
        at: now,
        createdAt: DateTime(2026, 11, 13, 10),
      );
      expect(CallBacks.calledBack(c, log), isFalse);
      expect(
        CallBacks.calledBack(c, <CallLogEntry>[
          call('0541234567', CallType.outgoing, DateTime(2026, 11, 13, 11)),
        ]),
        isFalse,
        reason: 'no answer',
      );
      expect(
        CallBacks.calledBack(c, <CallLogEntry>[
          call(
            '0541234567',
            CallType.outgoing,
            DateTime(2026, 11, 13, 11),
            seconds: 30,
          ),
        ]),
        isTrue,
      );
    });

    test('the task is written the way ZT Tasks reads it', () {
      final Map<String, Object?> json = callBackTaskJson(
        id: 't1',
        title: 'Call Dana Cohen back',
        number: '+972 54-123-4567',
        due: DateTime(2026, 11, 13, 23),
        now: now,
        contactId: 'dana',
      );
      expect(json['title'], 'Call Dana Cohen back');
      expect(json['dueDate'], '2026-11-13T23:00:00.000');
      expect(json['reminderAt'], isNull);
      expect(json['links'], <String>['tel:+972541234567']);
      expect(json['contactIds'], <String>['dana']);
      expect(json['isCompleted'], isFalse);
      // The default collection: no kind, schema version 1.
      expect(json.containsKey('kind'), isFalse);
      expect(json[ZtCollection.versionKey], 1);
    });
  });

  group('private call log', () {
    test('vault calls join the shared log, newest first', () {
      final List<CallLogEntry> all =
          mergeCalls(log.take(2).toList(), <BackedUpCall>[
            BackedUpCall(
              id: 'p1',
              number: '0541234567',
              type: 1,
              date: DateTime(2026, 11, 12, 20),
              durationSeconds: 5,
            ),
          ]);
      expect(all.map((CallLogEntry e) => e.isPrivate), <bool>[
        false,
        true,
        false,
      ]);
      expect(all[1].privateId, 'p1');
    });

    test('private contacts go to the Android side as hashed keys', () {
      final ScreeningRules rules = ScreeningRules.build(
        contacts: const <PhoneContact>[dana, avi],
        settings: const <ContactCallSettings>[
          ContactCallSettings(contactId: 'dana', privateLog: true),
        ],
        protection: const CallProtection(),
      );
      expect(rules.privateKeys, <String>['541234567']);
      expect(
        rules.same(
          ScreeningRules.build(
            contacts: const <PhoneContact>[dana, avi],
            settings: const <ContactCallSettings>[],
            protection: const CallProtection(),
          ),
        ),
        isFalse,
      );
    });
  });

  group('screens', () {
    Future<void> pump(
      WidgetTester tester,
      Widget home, {
      List<CallLogEntry> shared = const <CallLogEntry>[],
      List<BackedUpCall> private = const <BackedUpCall>[],
      List<CallBack> callBacks = const <CallBack>[],
      Locale locale = ZtLanguages.english,
    }) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            phoneContactsProvider.overrideWith(
              (ref) => Stream<List<PhoneContact>>.value(const <PhoneContact>[
                dana,
                avi,
              ]),
            ),
            callLogProvider.overrideWith((ref) async => shared),
            privateCallsProvider.overrideWith(
              (ref) => Stream<List<BackedUpCall>>.value(private),
            ),
            callBacksProvider.overrideWith(
              (ref) => Stream<List<CallBack>>.value(callBacks),
            ),
            statsCallsProvider.overrideWith(
              (ref) async => mergeCalls(shared, private),
            ),
          ],
          child: MaterialApp(
            locale: locale,
            supportedLocales: ZtLanguages.supported,
            localizationsDelegates: const <LocalizationsDelegate<Object>>[
              AppL10n.delegate,
              ...ZtLanguages.delegates,
            ],
            home: Scaffold(body: home),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Recents: call back reminders sit above the calls, and '
        'private calls carry a lock', (WidgetTester tester) async {
      await pump(
        tester,
        const RecentsPage(),
        shared: <CallLogEntry>[log[1]],
        private: <BackedUpCall>[
          BackedUpCall(
            id: 'p1',
            number: '0541234567',
            type: 2,
            date: DateTime.now(),
            durationSeconds: 60,
          ),
        ],
        callBacks: <CallBack>[
          CallBack(
            id: 'cb1',
            number: '0527654321',
            name: 'Avi',
            at: DateTime.now().add(const Duration(hours: 1)),
            createdAt: DateTime.now(),
          ),
        ],
      );
      final Finder reminder = find.text('Call back Avi');
      expect(reminder, findsOneWidget);
      final Finder privateRow = find.text('Dana Cohen');
      expect(privateRow, findsOneWidget);
      expect(
        tester.getRect(reminder).bottom,
        lessThan(tester.getRect(privateRow).top),
      );
      // The chips, then the reminder.
      expect(
        tester.getRect(find.text('Call stats')).bottom,
        lessThanOrEqualTo(tester.getRect(reminder).top),
      );
      final Finder lock = find.byIcon(Icons.lock_outline);
      expect(lock, findsOneWidget);
      // On Dana's row, not Avi's.
      final Rect lockRect = tester.getRect(lock);
      final Rect danaRect = tester.getRect(privateRow);
      expect(lockRect.top, greaterThan(danaRect.top));
      expect(lockRect.top - danaRect.bottom, lessThan(30));
      expect(find.byTooltip('Cancel reminder'), findsOneWidget);
    });

    testWidgets('Stats: totals, then weekly bars, then people; taller bar '
        'for more talk', (WidgetTester tester) async {
      await pump(tester, CallStatsPage(now: now), shared: log);
      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();
      expect(find.text('4'), findsWidgets);
      expect(find.text('13 min'), findsOneWidget);
      final double totals = tester.getRect(find.text('Talk time')).bottom;
      final double weeks = tester.getRect(find.text('Last 8 weeks')).top;
      final double people = tester
          .getRect(find.text('Who you talk to most'))
          .top;
      expect(totals, lessThan(weeks));
      expect(weeks, lessThan(people));
      final double thisWeek = tester
          .getSize(
            find.byKey(
              ValueKey<String>(
                'week-bar-${DateTime(2026, 11, 8).toIso8601String()}',
              ),
            ),
          )
          .height;
      final double emptyWeek = tester
          .getSize(
            find.byKey(
              ValueKey<String>(
                'week-bar-${DateTime(2026, 11, 1).toIso8601String()}',
              ),
            ),
          )
          .height;
      expect(thisWeek, greaterThan(emptyWeek * 10));
      final Finder dana = find.text('Dana Cohen');
      final Finder avi = find.text('Avi');
      expect(tester.getRect(dana).top, lessThan(tester.getRect(avi).top));
      expect(find.text('2 calls · 11 min'), findsOneWidget);
    });

    testWidgets('Stats in Hebrew', (WidgetTester tester) async {
      await pump(
        tester,
        CallStatsPage(now: now),
        shared: log,
        locale: ZtLanguages.hebrew,
      );
      expect(find.text('סטטיסטיקת שיחות'), findsOneWidget);
      expect(find.text('עם מי דיברת הכי הרבה'), findsOneWidget);
    });
  });
}
