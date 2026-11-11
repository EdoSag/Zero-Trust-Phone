import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/dialpad_page.dart';
import 'package:zerotrust_phone/pages/recents_page.dart';

void main() {
  test('every English string has a Hebrew translation with the same '
      'placeholders', () {
    Map<String, dynamic> read(String name) =>
        jsonDecode(File('lib/l10n/$name').readAsStringSync())
            as Map<String, dynamic>;
    final Map<String, dynamic> en = read('app_en.arb');
    final Map<String, dynamic> he = read('app_he.arb');
    final RegExp placeholder = RegExp(r'\{(\w+)[,}]|%[sd]');
    Set<String> names(String s) =>
        placeholder.allMatches(s).map((Match m) => m[1] ?? m[0]!).toSet();
    for (final String key in en.keys.where((String k) => !k.startsWith('@'))) {
      expect(he[key], isA<String>(), reason: 'app_he.arb is missing "$key"');
      expect(names(he[key] as String), names(en[key] as String), reason: key);
    }
  });

  testWidgets('Hebrew: the keypad still reads 1 2 3 from the left', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: ZtLanguages.hebrew,
        supportedLocales: ZtLanguages.supported,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          AppL10n.delegate,
          ...ZtLanguages.delegates,
        ],
        home: Scaffold(body: DialKeypad(onKey: (_) {})),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(Scaffold))),
      TextDirection.rtl,
    );
    final Rect one = tester.getRect(find.text('1'));
    final Rect three = tester.getRect(find.text('3'));
    expect(one.right, lessThan(three.left));
    expect(find.bySemanticsLabel('0, לחיצה ארוכה לפלוס'), findsOneWidget);
  });

  testWidgets('day labels and call filters follow the language', (
    WidgetTester tester,
  ) async {
    late AppL10n l;
    await tester.pumpWidget(
      MaterialApp(
        locale: ZtLanguages.hebrew,
        supportedLocales: ZtLanguages.supported,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          AppL10n.delegate,
          ...ZtLanguages.delegates,
        ],
        home: Builder(
          builder: (BuildContext context) {
            l = context.l10n;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final DateTime now = DateTime(2026, 11, 9, 12);
    expect(dayLabel(DateTime(2026, 11, 9, 1), now), 'היום');
    expect(dayLabel(DateTime(2026, 11, 8, 1), now), 'אתמול');
    expect(dayLabel(DateTime(2026, 3, 2), now), '2 מרץ');
    expect(RecentsFilter.missed.label(l), 'שלא נענתה');
    expect(RecentsFilter.blocked.empty(l), 'אין שיחות חסומות');
  });
}
