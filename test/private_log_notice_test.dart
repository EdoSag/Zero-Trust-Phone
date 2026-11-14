import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/contact_call_settings_page.dart';
import 'package:zerotrust_phone/services/private_calls.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

class FakePhoneData extends PhoneData {
  FakePhoneData(super.ref);
  final List<ContactCallSettings> saved = <ContactCallSettings>[];

  @override
  Future<void> saveContactSettings(ContactCallSettings s) async => saved.add(s);
}

class FakePrivateCalls extends PrivateCalls {
  FakePrivateCalls(super.ref);
  int moves = 0;

  @override
  Future<int> moveExisting(PhoneContact contact) async {
    moves++;
    return 0;
  }
}

/// The private call log's limits (P23) are spelled out before it's on.
void main() {
  const PhoneContact dana = PhoneContact(
    id: 'dana',
    name: 'Dana Cohen',
    phones: <String>['+972541234567'],
  );
  late FakePhoneData data;
  FakePrivateCalls? privateCalls;

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = ZtLanguages.english,
  }) async {
    privateCalls = null;
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneDataProvider.overrideWith((ref) => data = FakePhoneData(ref)),
          privateCallsServiceProvider.overrideWith(
            (ref) => privateCalls = FakePrivateCalls(ref),
          ),
          contactSettingsProvider.overrideWith(
            (ref) => Stream<List<ContactCallSettings>>.value(
              const <ContactCallSettings>[],
            ),
          ),
          phoneAccountsProvider.overrideWith(
            (ref) async => const <PhoneAccount>[],
          ),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: ZtLanguages.supported,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppL10n.delegate,
            ...ZtLanguages.delegates,
          ],
          home: const ContactCallSettingsPage(contact: dana),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final Finder limits = find.byKey(
    const ValueKey<String>('private-log-limits'),
  );

  testWidgets('the switch says the carrier keeps its own record, and the '
      'hide switch names emergency numbers', (WidgetTester tester) async {
    await pump(tester);
    expect(
      find.textContaining('Your carrier still keeps its own record'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Emergency numbers always see your number'),
      findsOneWidget,
    );
  });

  testWidgets('turning it on lists the three limits first; Cancel leaves '
      'it off', (WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.text('Private call log'));
    await tester.pumpAndSettle();
    expect(limits, findsOneWidget);
    final Finder seconds = find.textContaining('for a few seconds');
    final Finder notDefault = find.textContaining(
      "isn't your default Phone app",
    );
    final Finder carrier = find.textContaining('records and bill');
    for (final Finder f in <Finder>[seconds, notDefault, carrier]) {
      expect(find.descendant(of: limits, matching: f), findsOneWidget);
    }
    // In that order, one under the other.
    expect(
      tester.getRect(seconds).top,
      lessThan(tester.getRect(notDefault).top),
    );
    expect(
      tester.getRect(notDefault).top,
      lessThan(tester.getRect(carrier).top),
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(data.saved, isEmpty);
    expect(privateCalls?.moves ?? 0, 0);
  });

  testWidgets('"Turn on" saves it and moves past calls', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Private call log'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(data.saved.single.privateLog, isTrue);
    expect(privateCalls?.moves, 1);
  });

  testWidgets('Hebrew', (WidgetTester tester) async {
    await pump(tester, locale: ZtLanguages.hebrew);
    await tester.tap(find.text('יומן שיחות פרטי'));
    await tester.pumpAndSettle();
    expect(find.text('לפני שמפעילים'), findsOneWidget);
    expect(find.textContaining('הרישומים והחשבון'), findsOneWidget);
  });
}
