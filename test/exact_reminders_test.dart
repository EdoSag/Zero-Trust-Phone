import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/call_back_sheet.dart';
import 'package:zerotrust_phone/services/call_backs.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

class FakeTelecom extends Telecom {
  FakeTelecom(this.state);
  ExactAlarmState? state;
  int opened = 0;
  int marked = 0;
  bool grantOnOpen = false;

  @override
  Future<ExactAlarmState?> exactAlarmState() async => state;

  @override
  Future<void> markExactAlarmsAsked() async {
    marked++;
    final ExactAlarmState? s = state;
    if (s != null) state = ExactAlarmState(exact: s.exact, asked: true);
  }

  @override
  Future<bool> openExactAlarmSettings() async {
    opened++;
    // Like Android: opening the page counts as asked; [grantOnOpen]
    // stands for the user switching it on there.
    state = ExactAlarmState(exact: grantOnOpen, asked: true);
    return true;
  }
}

class FakeCallBacks extends CallBacks {
  FakeCallBacks(super.ref);
  final List<DateTime> added = <DateTime>[];

  @override
  Future<bool> add({
    required String number,
    required DateTime at,
    PhoneContact? contact,
  }) async {
    added.add(at);
    return true;
  }
}

void main() {
  late FakeTelecom telecom;
  late FakeCallBacks callBacks;

  Future<void> pump(
    WidgetTester tester,
    ExactAlarmState? state, {
    Locale locale = ZtLanguages.english,
  }) async {
    telecom = FakeTelecom(state);
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          telecomProvider.overrideWithValue(telecom),
          callBacksServiceProvider.overrideWith(
            (ref) => callBacks = FakeCallBacks(ref),
          ),
          phoneContactsProvider.overrideWith(
            (ref) => Stream<List<PhoneContact>>.value(const <PhoneContact>[]),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: ZtLanguages.supported,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppL10n.delegate,
            ...ZtLanguages.delegates,
          ],
          home: Scaffold(
            body: Consumer(
              builder: (BuildContext context, WidgetRef ref, _) => TextButton(
                onPressed: () => showCallBackSheet(
                  context,
                  ref,
                  number: '0541234567',
                  now: DateTime(2026, 11, 14, 10),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final Finder inexact = find.byKey(
    const ValueKey<String>('call-back-inexact'),
  );

  testWidgets('without "Alarms & reminders": the sheet says reminders can be '
      'late, above the choices, and the first reminder asks once', (
    WidgetTester tester,
  ) async {
    await pump(tester, const ExactAlarmState(exact: false, asked: false));
    expect(inexact, findsOneWidget);
    expect(
      tester.getTopLeft(inexact).dy,
      lessThan(tester.getTopLeft(find.text('In 15 minutes')).dy),
    );

    await tester.tap(find.text('In 1 hour'));
    await tester.pumpAndSettle();
    expect(callBacks.added, <DateTime>[DateTime(2026, 11, 14, 11)]);
    expect(find.text('Remind you on the minute?'), findsOneWidget);
    expect(telecom.marked, 1);
    // "Allow" sits after "Not now" (end side).
    expect(
      tester.getTopLeft(find.text('Allow')).dx,
      greaterThan(tester.getTopLeft(find.text('Not now')).dx),
    );
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(telecom.opened, 1);
    expect(find.text('Remind you on the minute?'), findsNothing);
  });

  testWidgets('declined before: no second ask, reminder still set', (
    WidgetTester tester,
  ) async {
    await pump(tester, const ExactAlarmState(exact: false, asked: true));
    expect(inexact, findsOneWidget);
    await tester.tap(find.text('In 1 hour'));
    await tester.pumpAndSettle();
    expect(callBacks.added, hasLength(1));
    expect(find.text('Remind you on the minute?'), findsNothing);
    expect(telecom.opened, 0);
  });

  testWidgets('"Not now" keeps the inexact reminder and opens nothing', (
    WidgetTester tester,
  ) async {
    await pump(tester, const ExactAlarmState(exact: false, asked: false));
    await tester.tap(find.text('In 1 hour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(callBacks.added, hasLength(1));
    expect(telecom.opened, 0);
    expect(telecom.marked, 1);
  });

  testWidgets('allowed: no note and no ask', (WidgetTester tester) async {
    await pump(tester, const ExactAlarmState(exact: true, asked: false));
    expect(inexact, findsNothing);
    await tester.tap(find.text('In 1 hour'));
    await tester.pumpAndSettle();
    expect(find.text('Remind you on the minute?'), findsNothing);
    expect(telecom.marked, 0);
  });

  testWidgets('Hebrew: the note and the question are translated', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      const ExactAlarmState(exact: false, asked: false),
      locale: ZtLanguages.hebrew,
    );
    expect(find.text('תזכורות יכולות לאחר בכמה דקות'), findsOneWidget);
    await tester.tap(find.text('בעוד שעה'));
    await tester.pumpAndSettle();
    expect(find.text('להזכיר בדיוק בזמן?'), findsOneWidget);
  });

  testWidgets('allowed from the note in the sheet: no second ask', (
    WidgetTester tester,
  ) async {
    await pump(tester, const ExactAlarmState(exact: false, asked: false));
    telecom.grantOnOpen = true;
    await tester.tap(inexact);
    await tester.pumpAndSettle();
    await tester.tap(find.text('In 1 hour'));
    await tester.pumpAndSettle();
    expect(callBacks.added, hasLength(1));
    expect(find.text('Remind you on the minute?'), findsNothing);
    expect(telecom.opened, 1);
  });

  testWidgets('note opened but left off: still no second ask', (
    WidgetTester tester,
  ) async {
    await pump(tester, const ExactAlarmState(exact: false, asked: false));
    await tester.tap(inexact);
    await tester.pumpAndSettle();
    await tester.tap(find.text('In 1 hour'));
    await tester.pumpAndSettle();
    expect(find.text('Remind you on the minute?'), findsNothing);
    expect(telecom.opened, 1);
  });
}
