import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/dialpad_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/dial_search.dart';

/// Smart dialpad search in English and Hebrew (P14).
void main() {
  PhoneContact contact(
    String name, {
    List<String> phones = const <String>['+972 54-000-0000'],
    String company = '',
  }) => PhoneContact(id: name, name: name, phones: phones, company: company);

  List<String> names(List<PhoneContact> all, String digits) => <String>[
    for (final DialMatch m in DialSearch.search(all, digits)) m.contact.name,
  ];

  test('English names match by any word, run on, or initials', () {
    expect(
      DialSearch.matchName('Ada Lovelace', '232'),
      DialMatchKind.nameStart,
    );
    expect(
      DialSearch.matchName('Ada Lovelace', '2325'),
      DialMatchKind.nameStart,
    );
    expect(DialSearch.matchName('Ada Lovelace', '568'), DialMatchKind.nameWord);
    expect(DialSearch.matchName('Ada Lovelace', '25'), DialMatchKind.initials);
    expect(DialSearch.matchName('Ada Lovelace', '999'), isNull);
    expect(DialSearch.matchName('Ada', ''), isNull);
    expect(DialSearch.matchName("O'Brien", '627'), DialMatchKind.nameStart);
    expect(DialSearch.matchName('José', '5673'), DialMatchKind.nameStart);
  });

  test('Hebrew letters sit on the Israeli keypad keys', () {
    // ד ה ו = 2, א ב ג = 3, מ נ = 4, י כ ל = 5, ז ח ט = 6, ר ש ת = 7,
    // צ ק = 8, ס ע פ = 9.
    expect(DialSearch.encode('דהו'), '222');
    expect(DialSearch.encode('אבג'), '333');
    expect(DialSearch.encode('מנ'), '44');
    expect(DialSearch.encode('יכל'), '555');
    expect(DialSearch.encode('זחט'), '666');
    expect(DialSearch.encode('רשת'), '777');
    expect(DialSearch.encode('צק'), '88');
    expect(DialSearch.encode('סעפ'), '999');
    // Final letters are typed as their usual letter.
    expect(DialSearch.encode('םןךףץ'), '44598');
    // Vowel points, geresh and apostrophes don't split or count.
    expect(DialSearch.encode('שָׁלוֹם'), DialSearch.encode('שלום'));
    expect(DialSearch.encode("צ'רלי"), '8755');
    expect(DialSearch.encode('צ׳רלי'), '8755');
  });

  test('Hebrew names match by first name, surname or initials', () {
    // משה כהן: מ4 ש7 ה2, כ5 ה2 ן4.
    expect(DialSearch.matchName('משה כהן', '472'), DialMatchKind.nameStart);
    expect(DialSearch.matchName('משה כהן', '524'), DialMatchKind.nameWord);
    expect(DialSearch.matchName('משה כהן', '45'), DialMatchKind.initials);
    // Mixed scripts in one name.
    expect(DialSearch.matchName('Dana לוי', '525'), DialMatchKind.nameWord);
  });

  test('numbers match as stored, national with 0, or without it', () {
    expect(DialSearch.matchNumber('+972 54-123-4567', '0541'), isTrue);
    expect(DialSearch.matchNumber('+972 54-123-4567', '541234'), isTrue);
    expect(DialSearch.matchNumber('+972 54-123-4567', '97254'), isTrue);
    expect(DialSearch.matchNumber('00972541234567', '0541'), isTrue);
    expect(DialSearch.matchNumber('+1 415 555 0100', '4155'), isTrue);
    expect(DialSearch.matchNumber('+1 415 555 0100', '0415'), isFalse);
    expect(DialSearch.matchNumber('054-123-4567', '1234'), isTrue);
    expect(DialSearch.matchNumber('054-123-4567', '999'), isFalse);
  });

  test('search ranks name start, other words, initials, company, number', () {
    final List<PhoneContact> all = <PhoneContact>[
      contact('Number Only', phones: const <String>['+972 52-526-0000']),
      contact('Worker', company: 'Jade Ltd'), // Jade = 5233
      contact('Bob Dylan'), // initials 23? B2 D3 -> "23"
      contact('Mia Jade'), // second word Jade
      contact('Jade West'), // first word Jade
    ];
    expect(names(all, '5233'), <String>['Jade West', 'Mia Jade', 'Worker']);
    expect(names(all, '23'), <String>['Bob Dylan']);
    expect(names(all, '5252'), <String>['Number Only']);
    // A number match offers only the numbers that matched.
    final PhoneContact two = contact(
      'Two Numbers',
      phones: const <String>['+972 3-555-1111', '+972 54-777-2222'],
    );
    final List<DialMatch> found = DialSearch.search(<PhoneContact>[
      two,
    ], '0547');
    expect(found.single.phones, <String>['+972 54-777-2222']);
    // A name match offers them all.
    expect(
      DialSearch.search(<PhoneContact>[two], '896').single.phones,
      two.phones,
    );
  });

  test('contacts without a number are left out', () {
    expect(
      names(<PhoneContact>[contact('Ada', phones: const <String>[])], '2'),
      isEmpty,
    );
  });

  Future<void> pump(
    WidgetTester tester,
    Locale locale,
    String number,
    List<PhoneContact> contacts,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneContactsProvider.overrideWith(
            (ref) => Stream<List<PhoneContact>>.value(contacts),
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

  testWidgets('typing digits lists Hebrew contacts and company matches', (
    WidgetTester tester,
  ) async {
    await pump(tester, ZtLanguages.hebrew, '524', <PhoneContact>[
      contact('משה כהן', phones: const <String>['+972 54-111-2222']),
      contact(
        'Ron',
        company: 'כהן ובניו',
        phones: const <String>['03-555-0000'],
      ),
      contact('Other'),
    ]);
    expect(find.text('משה כהן'), findsOneWidget);
    expect(find.text('Ron'), findsOneWidget);
    expect(find.textContaining('כהן ובניו · '), findsOneWidget);
    expect(find.text('Other'), findsNothing);
    // The rows sit above the keypad, one under the other.
    final Rect first = tester.getRect(find.text('משה כהן'));
    final Rect second = tester.getRect(find.text('Ron'));
    expect(second.top, greaterThanOrEqualTo(first.bottom));
  });

  testWidgets('the keypad shows Hebrew letters only in Hebrew', (
    WidgetTester tester,
  ) async {
    await pump(tester, ZtLanguages.hebrew, '', const <PhoneContact>[]);
    expect(find.text('ABC דהו'), findsOneWidget);
    expect(find.text('WXYZ סעפ'), findsOneWidget);
    await pump(tester, ZtLanguages.english, '', const <PhoneContact>[]);
    expect(find.text('ABC'), findsOneWidget);
    expect(find.textContaining('דהו'), findsNothing);
  });
}
