import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:zerotrust_phone/util/countries.dart';
import 'package:zerotrust_phone/util/dial_sequence.dart';

/// Country and local time for an international number (P16): "Germany,
/// 03:12 there now". Worked out on the phone from the calling code and the
/// time zone rules shipped with the app.
class CountryHint {
  const CountryHint({
    required this.country,
    required this.earliest,
    this.latest,
  });

  final Country country;

  /// The time there now; for a country with several zones, its earliest.
  final DateTime earliest;

  /// The latest time across the country's zones, when they differ.
  final DateTime? latest;
}

abstract final class CountryHints {
  static bool _zonesLoaded = false;

  /// Israeli carriers' international prefixes ("014 49 …" = "+49 …").
  static const List<String> israeliCarrierPrefixes = <String>[
    '012', '013', '014', '015', '017', '018', '019', //
  ];

  /// The digits after the international prefix (the calling code and
  /// number), or null when [typed] isn't dialled as international.
  /// [homeIso] is the SIM's country, which decides local prefixes.
  static String? internationalDigits(String typed, {String? homeIso}) {
    final String number = DialSequence.split(typed).$1.trim();
    final String digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (number.startsWith('+')) return digits;
    if (digits.startsWith('00')) return digits.substring(2);
    if (homeIso?.toUpperCase() == 'IL') {
      for (final String p in israeliCarrierPrefixes) {
        if (digits.startsWith(p) && digits.length > p.length) {
          return digits.substring(p.length);
        }
      }
    }
    // North America dials out with 011.
    if ((homeIso?.toUpperCase() == 'US' || homeIso?.toUpperCase() == 'CA') &&
        digits.startsWith('011')) {
      return digits.substring(3);
    }
    return null;
  }

  /// The country and its time zones for [typed], or null when it isn't
  /// international or the code isn't complete yet.
  static (Country, List<String>)? countryFor(String typed, {String? homeIso}) {
    final String? digits = internationalDigits(typed, homeIso: homeIso);
    if (digits == null || digits.isEmpty) return null;
    if (digits.startsWith('1')) {
      // +1 is shared by the US, Canada and the Caribbean: the area code says.
      if (digits.length < 4) return null;
      final String area = digits.substring(1, 4);
      final String iso = nanpAreas[area] ?? 'US';
      final Country c = countries.firstWhere((Country c) => c.iso == iso);
      if (iso == 'CA') {
        return (c, canadaZones[area] ?? const <String>['America/Toronto']);
      }
      return (c, c.zones);
    }
    Country? best;
    for (final Country c in countries) {
      if (c.code == '1') continue;
      if (digits.startsWith(c.code) &&
          (best == null || c.code.length > best.code.length)) {
        best = c;
      }
    }
    // Wait for a digit after the code, so "+3" doesn't flash a country.
    if (best == null || digits.length <= best.code.length) return null;
    return (best, best.zones);
  }

  /// The hint for [typed] at [now], or null when there's nothing to say:
  /// not international, or a call to the SIM's own country.
  static CountryHint? forNumber(
    String typed, {
    String? homeIso,
    DateTime? now,
  }) {
    final (Country, List<String>)? found = countryFor(typed, homeIso: homeIso);
    if (found == null) return null;
    final (Country country, List<String> zones) = found;
    if (homeIso != null && country.iso == homeIso.toUpperCase()) return null;
    if (!_zonesLoaded) {
      tzdata.initializeTimeZones();
      _zonesLoaded = true;
    }
    final DateTime at = (now ?? DateTime.now()).toUtc();
    final List<DateTime> times = <DateTime>[];
    for (final String zone in zones) {
      try {
        final tz.TZDateTime t = tz.TZDateTime.from(at, tz.getLocation(zone));
        // A plain local DateTime with the wall-clock time there.
        times.add(DateTime(t.year, t.month, t.day, t.hour, t.minute));
      } on tz.LocationNotFoundException {
        continue;
      }
    }
    if (times.isEmpty) return null;
    times.sort();
    final DateTime first = times.first;
    final DateTime last = times.last;
    return CountryHint(
      country: country,
      earliest: first,
      latest: last == first ? null : last,
    );
  }
}
