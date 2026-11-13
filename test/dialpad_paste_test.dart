import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/dialpad_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

/// Paste and clean numbers on the dialpad (P13).
void main() {
  String? clipboard;

  setUp(() {
    clipboard = null;
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.getData') {
            return clipboard == null
                ? null
                : <String, Object?>{'text': clipboard};
          }
          if (call.method == 'Clipboard.hasStrings') {
            return <String, Object?>{'value': clipboard != null};
          }
          return null;
        });
  });

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = ZtLanguages.english,
    String? initialText,
  }) async {
    // A phone-sized screen.
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneContactsProvider.overrideWith(
            (ref) => Stream<List<PhoneContact>>.value(const <PhoneContact>[]),
          ),
          callLogProvider.overrideWith((ref) async => const <CallLogEntry>[]),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: ZtLanguages.supported,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppL10n.delegate,
            ...ZtLanguages.delegates,
          ],
          home: DialpadPage(initialText: initialText),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String typed(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('paste sits beside the number and fills it in, cleaned', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    final Finder paste = find.byTooltip('Paste a number');
    expect(paste, findsOneWidget);
    // On the number's row, to the right of the field, above the keypad.
    final Rect field = tester.getRect(find.byType(TextField));
    final Rect button = tester.getRect(paste);
    expect(button.center.dy, closeTo(field.center.dy, 4));
    expect(button.left, greaterThanOrEqualTo(field.right - 1));
    expect(button.bottom, lessThan(tester.getRect(find.text('1')).top));

    clipboard = 'Dana Cohen\nMobile: +972 (0)52-765-4321';
    await tester.tap(paste);
    await tester.pumpAndSettle();
    expect(typed(tester), '+972527654321');
    // With a number in, backspace takes the paste button's place.
    expect(paste, findsNothing);
    expect(find.byTooltip('Delete'), findsOneWidget);
  });

  testWidgets('several numbers: pick one from a list', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    clipboard = 'Office 03-1234567, mobile 054-123-4567';
    await tester.tap(find.byTooltip('Paste a number'));
    await tester.pumpAndSettle();

    expect(find.text('Which number?'), findsOneWidget);
    final Rect first = tester.getRect(find.textContaining('031234567'));
    final Rect second = tester.getRect(find.textContaining('0541234567'));
    expect(first.bottom, lessThanOrEqualTo(second.top));
    await tester.tap(find.textContaining('0541234567'));
    await tester.pumpAndSettle();
    expect(typed(tester), '0541234567');
  });

  testWidgets('no number: says so and leaves the dialpad empty', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    clipboard = 'see you at 8';
    await tester.tap(find.byTooltip('Paste a number'));
    await tester.pump();
    expect(
      find.text('No phone number found in the copied text'),
      findsOneWidget,
    );
    expect(typed(tester), '');
  });

  testWidgets('Hebrew: text shared from another app fills the number', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      locale: ZtLanguages.hebrew,
      initialText: 'הנייד של דני: 052-765-4321',
    );
    expect(typed(tester), '0527654321');
    expect(find.byTooltip('מחיקה'), findsOneWidget);
  });
}
