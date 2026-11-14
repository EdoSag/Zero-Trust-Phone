import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/dialpad_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

/// The dialpad's country hint (P16), pause keys (P15) and hide-my-number
/// switch (P22).
void main() {
  Future<void> pump(
    WidgetTester tester, {
    Locale locale = ZtLanguages.english,
    String number = '',
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneContactsProvider.overrideWith(
            (ref) => Stream<List<PhoneContact>>.value(const <PhoneContact>[]),
          ),
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
          home: DialpadPage(initialNumber: number),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String hint(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey<String>('dial-hint')))
      .data!;

  String typed(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('an international number shows its country between the '
      'number and the keypad', (WidgetTester tester) async {
    await pump(tester, number: '+4930123456');
    expect(hint(tester), startsWith('🇩🇪 Germany · '));
    expect(hint(tester), endsWith(' there now'));
    final Rect line = tester.getRect(
      find.byKey(const ValueKey<String>('dial-hint')),
    );
    expect(
      line.top,
      greaterThanOrEqualTo(tester.getRect(find.byType(TextField)).bottom - 1),
    );
    expect(line.bottom, lessThanOrEqualTo(tester.getRect(find.text('1')).top));
  });

  testWidgets('local Israeli numbers show no hint', (
    WidgetTester tester,
  ) async {
    await pump(tester, number: '0541234567');
    expect(hint(tester), isEmpty);
  });

  testWidgets('the hint is in Hebrew too', (WidgetTester tester) async {
    await pump(tester, locale: ZtLanguages.hebrew, number: '00441234567');
    expect(hint(tester), contains('בריטניה'));
    expect(hint(tester), contains('שם עכשיו'));
  });

  testWidgets('holding * types a pause and # a wait', (
    WidgetTester tester,
  ) async {
    await pump(tester, number: '031234567');
    await tester.longPress(find.text('*'));
    await tester.longPress(find.text('#'));
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(typed(tester), '031234567,;5');
  });

  testWidgets('hide my number is one tap, and says so under the number', (
    WidgetTester tester,
  ) async {
    await pump(tester, number: '+4930123456');
    final Finder hide = find.byTooltip('Hide my number on this call');
    expect(hide, findsOneWidget);
    await tester.tap(hide);
    await tester.pumpAndSettle();
    expect(hint(tester), endsWith(' · My number hidden'));
    expect(find.byTooltip('Show my number on this call'), findsOneWidget);
  });

  testWidgets('switching hide on says what it can\'t do, at the bottom', (
    WidgetTester tester,
  ) async {
    await pump(tester, number: '0541234567');
    await tester.tap(find.byTooltip('Hide my number on this call'));
    await tester.pumpAndSettle();
    final Finder notice = find.textContaining(
      'Emergency numbers always see it',
    );
    expect(notice, findsOneWidget);
    expect(find.textContaining('if your carrier allows it'), findsOneWidget);
    // A snackbar below the keypad, not on top of the number.
    expect(
      tester.getRect(notice).top,
      greaterThan(tester.getRect(find.byType(TextField)).bottom),
    );
    // Switching it off again clears the notice.
    await tester.tap(find.byTooltip('Show my number on this call'));
    await tester.pumpAndSettle();
    expect(notice, findsNothing);
  });

  testWidgets('the notice is in Hebrew too', (WidgetTester tester) async {
    await pump(tester, locale: ZtLanguages.hebrew, number: '0541234567');
    await tester.tap(find.byTooltip('הסתרת המספר שלי בשיחה הזו'));
    await tester.pumpAndSettle();
    expect(find.textContaining('מספרי חירום תמיד רואים אותו'), findsOneWidget);
  });
}
