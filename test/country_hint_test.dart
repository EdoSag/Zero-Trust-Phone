import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_phone/util/countries.dart';
import 'package:zerotrust_phone/util/country_hint.dart';

/// Country and local time while typing an international number (P16).
void main() {
  // 13 Nov 2026, 22:12 in Israel (UTC+2): 21:12 in Berlin.
  final DateTime now = DateTime.utc(2026, 11, 13, 20, 12);

  test('+49 is Germany, with the time there', () {
    final CountryHint? hint = CountryHints.forNumber(
      '+49 30 1234567',
      homeIso: 'IL',
      now: now,
    );
    expect(hint!.country.en, 'Germany');
    expect(hint.country.he, 'גרמניה');
    expect(hint.country.flag, '🇩🇪');
    expect(hint.earliest, DateTime(2026, 11, 13, 21, 12));
    expect(hint.latest, isNull);
  });

  test('00 and Israeli carrier prefixes count as international', () {
    for (final String typed in <String>[
      '0044 20 7946 0000',
      '014 44 20 7946',
    ]) {
      expect(
        CountryHints.forNumber(typed, homeIso: 'IL', now: now)!.country.en,
        'United Kingdom',
        reason: typed,
      );
    }
    // Abroad, 014 is just a local number.
    expect(CountryHints.forNumber('014 44 20 7946', homeIso: 'DE'), isNull);
  });

  test('local and own-country numbers show nothing', () {
    expect(CountryHints.forNumber('054-1234567', homeIso: 'IL'), isNull);
    expect(CountryHints.forNumber('+972 54 123 4567', homeIso: 'IL'), isNull);
    // Shown when calling Israel from abroad.
    expect(
      CountryHints.forNumber(
        '+972 54 123 4567',
        homeIso: 'US',
        now: now,
      )!.earliest,
      DateTime(2026, 11, 13, 22, 12),
    );
  });

  test('waits for the whole calling code', () {
    expect(CountryHints.forNumber('+3', homeIso: 'IL'), isNull);
    expect(CountryHints.forNumber('+1 21', homeIso: 'IL'), isNull);
    expect(CountryHints.forNumber('+35', homeIso: 'IL'), isNull);
    expect(
      CountryHints.forNumber('+351 2', homeIso: 'IL', now: now)!.country.en,
      'Portugal',
    );
  });

  test('+1 is told apart by area code', () {
    expect(
      CountryHints.forNumber(
        '+1 876 555 0100',
        homeIso: 'IL',
        now: now,
      )!.country.en,
      'Jamaica',
    );
    final (Country, List<String>) winnipeg = CountryHints.countryFor(
      '+1 204 555 0100',
      homeIso: 'IL',
    )!;
    expect(winnipeg.$1.en, 'Canada');
    expect(winnipeg.$2, <String>['America/Winnipeg']);
    // The US spans zones: New York 15:12 to Los Angeles 12:12.
    final CountryHint us = CountryHints.forNumber(
      '+1 212 555 0100',
      homeIso: 'IL',
      now: now,
    )!;
    expect(us.country.en, 'United States');
    expect(us.earliest, DateTime(2026, 11, 13, 12, 12));
    expect(us.latest, DateTime(2026, 11, 13, 15, 12));
  });

  test('a time past midnight there is on the next day', () {
    final CountryHint tokyo = CountryHints.forNumber(
      '+81 3 1234 5678',
      homeIso: 'IL',
      now: now,
    )!;
    expect(tokyo.earliest, DateTime(2026, 11, 14, 5, 12));
  });

  test('Kazakhstan shares +7 with Russia', () {
    expect(
      CountryHints.forNumber(
        '+7 701 123 4567',
        homeIso: 'IL',
        now: now,
      )!.country.en,
      'Kazakhstan',
    );
    expect(
      CountryHints.forNumber(
        '+7 495 123 4567',
        homeIso: 'IL',
        now: now,
      )!.country.en,
      'Russia',
    );
  });
}
