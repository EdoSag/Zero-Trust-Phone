import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/app/call_comfort.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/dialpad_page.dart';
import 'package:zerotrust_phone/pages/keypad_settings_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

/// P17 keypad size and one-handed mode, P18 SIM picker with per-number
/// memory, P29 pocket-dial guard.
class FakeTelecom extends Telecom {
  FakeTelecom({
    this.sims = const <PhoneAccount>[],
    this.systemDefault,
    this.covered = false,
  });

  final List<PhoneAccount> sims;
  final String? systemDefault;
  bool covered;
  final List<(String, String?)> placed = <(String, String?)>[];
  final List<String> tones = <String>[];
  bool? flip;

  @override
  Future<List<PhoneAccount>> phoneAccounts() async => sims;

  @override
  Future<String?> defaultPhoneAccount() async => systemDefault;

  @override
  Future<bool> screenCovered() async => covered;

  @override
  Future<void> playKeyTone(String key) async => tones.add(key);

  @override
  Future<void> setCallComfort({
    required bool flipToSilence,
    required bool pocketGuard,
  }) async => flip = flipToSilence;

  @override
  Future<void> placeCall(
    String number, {
    String? account,
    bool rtt = false,
    bool video = false,
    bool hideCallerId = false,
  }) async => placed.add((number, account));

  @override
  Future<String?> simCountry() async => 'IL';

  @override
  Future<CallFeatures> callFeatures() async => const CallFeatures();
}

class FakePhoneData extends PhoneData {
  FakePhoneData(super.ref);
  final List<SimChoice> saved = <SimChoice>[];
  final List<String> deleted = <String>[];

  @override
  Future<void> saveSimChoice(SimChoice c) async => saved.add(c);

  @override
  Future<void> deleteSimChoice(String key) async => deleted.add(key);
}

const List<PhoneAccount> twoSims = <PhoneAccount>[
  PhoneAccount(id: 'sim-a', label: 'Partner'),
  PhoneAccount(id: 'sim-b', label: 'Work eSIM'),
];

void main() {
  late FakePhoneData data;

  Future<FakeTelecom> pump(
    WidgetTester tester, {
    FakeTelecom? telecom,
    CallComfort comfort = const CallComfort(),
    List<SimChoice> remembered = const <SimChoice>[],
    Widget? home,
    String number = '0541234567',
    Locale locale = ZtLanguages.english,
  }) async {
    final FakeTelecom t = telecom ?? FakeTelecom();
    final InMemoryPreferencesStore prefs = InMemoryPreferencesStore();
    prefs.values['call_comfort'] = _json(comfort);
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          telecomProvider.overrideWithValue(t),
          ztPreferencesStoreProvider.overrideWithValue(prefs),
          phoneContactsProvider.overrideWith(
            (ref) => Stream<List<PhoneContact>>.value(const <PhoneContact>[]),
          ),
          contactSettingsProvider.overrideWith(
            (ref) => Stream<List<ContactCallSettings>>.value(
              const <ContactCallSettings>[],
            ),
          ),
          simChoicesProvider.overrideWith(
            (ref) => Stream<List<SimChoice>>.value(remembered),
          ),
          phoneDataProvider.overrideWith((ref) => data = FakePhoneData(ref)),
          callLogProvider.overrideWith((ref) async => const <CallLogEntry>[]),
          homeCountryProvider.overrideWith((ref) async => 'IL'),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: ZtLanguages.supported,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppL10n.delegate,
            ...ZtLanguages.delegates,
          ],
          home: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? _) {
              // Data and the SIM memory are read as the dialpad opens.
              ref.watch(phoneDataProvider);
              ref.watch(simChoicesProvider);
              return home ?? DialpadPage(initialNumber: number);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return t;
  }

  Rect keyRect(WidgetTester tester, String digit) => tester.getRect(
    find.descendant(of: find.byType(DialKeypad), matching: find.text(digit)),
  );

  group('P17 keypad', () {
    testWidgets('one-handed left: the keypad sits on the left, with an arrow '
        'on the right that moves it across', (WidgetTester tester) async {
      await pump(tester, comfort: const CallComfort(hand: KeypadHand.left));
      final Rect one = keyRect(tester, '1');
      final Rect three = keyRect(tester, '3');
      final Rect arrow = tester.getRect(
        find.byKey(const ValueKey<String>('keypad-move')),
      );
      expect(three.right, lessThan(arrow.left));
      expect(one.left, lessThan(60));
      expect(arrow.right, greaterThan(340));
      await tester.tap(find.byKey(const ValueKey<String>('keypad-move')));
      await tester.pumpAndSettle();
      final Rect movedArrow = tester.getRect(
        find.byKey(const ValueKey<String>('keypad-move')),
      );
      expect(movedArrow.right, lessThan(keyRect(tester, '1').left));
      expect(movedArrow.left, lessThan(60));
    });

    testWidgets('one-handed mode keeps 1 2 3 left to right in Hebrew', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        comfort: const CallComfort(hand: KeypadHand.right),
        locale: ZtLanguages.hebrew,
      );
      expect(keyRect(tester, '1').left, lessThan(keyRect(tester, '3').left));
      // Right hand: the keypad is on the right, its arrow on the left.
      expect(
        tester.getRect(find.byKey(const ValueKey<String>('keypad-move'))).right,
        lessThan(keyRect(tester, '1').left),
      );
    });

    testWidgets('big keys are taller than normal keys, and the call button '
        'stays below the keypad', (WidgetTester tester) async {
      await pump(tester);
      final double normal = tester
          .getSize(
            find
                .ancestor(of: find.text('5'), matching: find.byType(InkWell))
                .first,
          )
          .height;
      await pump(tester, comfort: const CallComfort(largeKeys: true));
      final double big = tester
          .getSize(
            find
                .ancestor(of: find.text('5'), matching: find.byType(InkWell))
                .first,
          )
          .height;
      expect(big, greaterThan(normal));
      expect(
        tester.getRect(find.byKey(const ValueKey<String>('dial-call'))).top,
        greaterThanOrEqualTo(keyRect(tester, '0').bottom),
      );
    });

    testWidgets('a key plays its tone unless tones are off', (
      WidgetTester tester,
    ) async {
      FakeTelecom t = await pump(tester, number: '');
      await tester.tap(find.text('7').last);
      expect(t.tones, <String>['7']);
      t = await pump(
        tester,
        number: '',
        comfort: const CallComfort(keyTones: false),
      );
      await tester.tap(find.text('7').last);
      expect(t.tones, isEmpty);
    });

    testWidgets('settings: switching flip to silence tells Android', (
      WidgetTester tester,
    ) async {
      final FakeTelecom t = await pump(
        tester,
        home: const KeypadSettingsPage(),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('flip-to-silence')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey<String>('flip-to-silence')),
            )
            .value,
        isTrue,
      );
      expect(t.flip, isTrue);
    });
  });

  group('P18 SIM picker', () {
    testWidgets('one SIM: calls at once, no question', (
      WidgetTester tester,
    ) async {
      final FakeTelecom t = await pump(
        tester,
        telecom: FakeTelecom(sims: <PhoneAccount>[twoSims.first]),
      );
      await tester.tap(find.byKey(const ValueKey<String>('dial-call')));
      await tester.pumpAndSettle();
      expect(t.placed, <(String, String?)>[('0541234567', null)]);
    });

    testWidgets('two SIMs with a default in Android: no question', (
      WidgetTester tester,
    ) async {
      final FakeTelecom t = await pump(
        tester,
        telecom: FakeTelecom(sims: twoSims, systemDefault: 'sim-a'),
      );
      await tester.tap(find.byKey(const ValueKey<String>('dial-call')));
      await tester.pumpAndSettle();
      expect(t.placed.single.$2, isNull);
    });

    testWidgets('two SIMs: asks, and "Remember" saves the choice', (
      WidgetTester tester,
    ) async {
      final FakeTelecom t = await pump(
        tester,
        telecom: FakeTelecom(sims: twoSims),
      );
      await tester.tap(find.byKey(const ValueKey<String>('dial-call')));
      await tester.pumpAndSettle();
      expect(find.text('Call with'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('sim-remember')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work eSIM'));
      await tester.pumpAndSettle();
      expect(t.placed.single, ('0541234567', 'sim-b'));
      expect(data.saved.single.key, '541234567');
      expect(data.saved.single.accountId, 'sim-b');
    });

    testWidgets('closing the picker places no call', (
      WidgetTester tester,
    ) async {
      final FakeTelecom t = await pump(
        tester,
        telecom: FakeTelecom(sims: twoSims),
      );
      await tester.tap(find.byKey(const ValueKey<String>('dial-call')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(t.placed, isEmpty);
      expect(find.byType(DialpadPage), findsOneWidget);
    });

    testWidgets('a remembered SIM is used without asking, also for another '
        'spelling of the number', (WidgetTester tester) async {
      final FakeTelecom t = await pump(
        tester,
        number: '+972 54-123-4567',
        telecom: FakeTelecom(sims: twoSims),
        remembered: const <SimChoice>[
          SimChoice(
            key: '541234567',
            number: '0541234567',
            accountId: 'sim-b',
            accountLabel: 'Work eSIM',
          ),
        ],
      );
      await tester.tap(find.byKey(const ValueKey<String>('dial-call')));
      await tester.pumpAndSettle();
      expect(find.text('Call with'), findsNothing);
      expect(t.placed.single.$2, 'sim-b');
    });

    testWidgets('holding the call button always asks', (
      WidgetTester tester,
    ) async {
      final FakeTelecom t = await pump(
        tester,
        telecom: FakeTelecom(sims: twoSims, systemDefault: 'sim-a'),
      );
      await tester.longPress(find.byKey(const ValueKey<String>('dial-call')));
      await tester.pumpAndSettle();
      expect(find.text('Call with'), findsOneWidget);
      await tester.tap(find.text('Partner'));
      await tester.pumpAndSettle();
      expect(t.placed.single.$2, 'sim-a');
      expect(data.saved, isEmpty);
    });

    testWidgets('the picker is in Hebrew too', (WidgetTester tester) async {
      await pump(
        tester,
        telecom: FakeTelecom(sims: twoSims),
        locale: ZtLanguages.hebrew,
      );
      await tester.tap(find.byKey(const ValueKey<String>('dial-call')));
      await tester.pumpAndSettle();
      expect(find.text('חיוג עם'), findsOneWidget);
      expect(find.text('לזכור עבור המספר הזה'), findsOneWidget);
    });
  });

  group('P29 pocket-dial guard', () {
    testWidgets('a covered screen places no call and says why', (
      WidgetTester tester,
    ) async {
      final FakeTelecom t = await pump(
        tester,
        telecom: FakeTelecom(covered: true),
        comfort: const CallComfort(pocketGuard: true),
      );
      await tester.tap(find.byKey(const ValueKey<String>('dial-call')));
      await tester.pumpAndSettle();
      expect(t.placed, isEmpty);
      expect(find.textContaining('screen seems covered'), findsOneWidget);
    });

    testWidgets('guard off: a covered screen still calls', (
      WidgetTester tester,
    ) async {
      final FakeTelecom t = await pump(
        tester,
        telecom: FakeTelecom(covered: true),
      );
      await tester.tap(find.byKey(const ValueKey<String>('dial-call')));
      await tester.pumpAndSettle();
      expect(t.placed, hasLength(1));
    });
  });

  test('settings survive a round trip, and unknown values fall back', () {
    const CallComfort c = CallComfort(
      largeKeys: true,
      hand: KeypadHand.right,
      keyTones: false,
      haptics: KeypadHaptics.strong,
      flipToSilence: true,
      pocketGuard: true,
    );
    final CallComfort back = CallComfort.fromJson(c.toJson());
    expect(back.toJson(), c.toJson());
    final CallComfort odd = CallComfort.fromJson(<String, Object?>{
      'hand': 'middle',
      'haptics': 'huge',
    });
    expect(odd.hand, KeypadHand.both);
    expect(odd.haptics, KeypadHaptics.light);
    expect(odd.keyTones, isTrue);
  });
}

String _json(CallComfort c) =>
    '{"largeKeys":${c.largeKeys},"hand":"${c.hand.name}",'
    '"keyTones":${c.keyTones},"haptics":"${c.haptics.name}",'
    '"flipToSilence":${c.flipToSilence},"pocketGuard":${c.pocketGuard}}';
