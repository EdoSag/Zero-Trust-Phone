/// Finds phone numbers in any pasted or shared text (P13) and cleans them
/// so the dialer can call them: a message, an email signature, a web page,
/// in Hebrew or English.
///
/// What it fixes:
/// - Separators and brackets: `054-123 4567`, `(03) 123.4567`.
/// - International prefixes: `00972…` and a bare `972…` become `+972…`.
/// - The trunk zero written after a country code: `+972 (0)54…` and
///   `+972 054…` become `+97254…` (the same for other countries' `(0)`).
/// - Digits typed in Arabic-Indic or full-width forms, Unicode dashes and
///   spaces, and the invisible direction marks Hebrew text often carries.
///
/// Local numbers stay local (`0541234567` dials fine in Israel); Israeli
/// star numbers such as `*2700` are kept. Dates, times, prices and card
/// numbers are not numbers to call, so they are left out.
abstract final class PastedNumbers {
  /// Every callable number in [text], cleaned, in order, without repeats.
  static List<String> find(String text) {
    final String plain = _plainText(text);
    final List<String> found = <String>[];
    void add(String n) {
      if (n.isNotEmpty && !found.contains(n)) found.add(n);
    }

    for (final RegExpMatch m in _candidate.allMatches(plain)) {
      final String run = m[0]!.trim();
      if (run.startsWith('*')) {
        add(run.replaceAll(RegExp(r'[^0-9*]'), ''));
        continue;
      }
      if (_looksLikeDate(run)) continue;
      for (final String piece in _split(run)) {
        if (!_looksLikeDate(piece)) add(clean(piece));
      }
    }
    return found;
  }

  /// [raw] (one number, maybe with separators) as a dialable string, or ''
  /// when it isn't a phone number.
  static String clean(String raw) {
    String s = _plainText(raw).trim();
    if (RegExp(r'^\*\d{3,5}$').hasMatch(s)) return s;
    bool plus = s.startsWith('+');
    // "+44 (0)20 …": the bracketed zero is only for calls from inside.
    if (plus) s = s.replaceFirst(RegExp(r'\(\s*0\s*\)'), '');
    String digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (!plus && digits.startsWith('00')) {
      plus = true;
      digits = digits.substring(2);
    }
    // A bare 972 + Israeli number (11 or 12 digits, or 13 with the zero).
    if (!plus &&
        digits.startsWith('972') &&
        digits.length >= 11 &&
        digits.length <= 13) {
      plus = true;
    }
    // "+972 054…": Israel never keeps the trunk zero after +972.
    if (plus && digits.startsWith('9720')) {
      digits = '972${digits.substring(4)}';
    }
    if (plus) {
      return digits.length >= 8 && digits.length <= 15 ? '+$digits' : '';
    }
    return digits.length >= 7 && digits.length <= 15 ? digits : '';
  }

  /// A run of digits with the separators people write inside one number,
  /// or an Israeli star number. A space, dash, dot or slash on its own may
  /// sit between digit groups; a comma or a line break never does.
  static final RegExp _candidate = RegExp(
    r'\*\d{3,5}(?![\d])'
    r'|(?<![\w+])(?:\+|00)?[ ]?(?:\(\s*\d{1,4}\s*\)[ ]?)?\d'
    r'(?:(?:[ ]?[-.][ ]?|[ ]|/|[ ]?\(\s*\d{1,4}\s*\)[ ]?)?\d)*'
    r'(?![\w])',
  );

  /// One run can hold two numbers written side by side ("054-1234567
  /// 03-7654321") or a stray number before one ("Room 12 054-1234567").
  /// Splits it on spaces where one number ends and another starts.
  static List<String> _split(String run) {
    final List<String> out = <String>[];
    String acc = '';
    for (final String p in run.split(RegExp(r'\s+|/'))) {
      if (p.isEmpty) continue;
      if (acc.isEmpty) {
        acc = p;
        continue;
      }
      final String accDigits = acc.replaceAll(RegExp(r'[^0-9]'), '');
      final bool international =
          acc.startsWith('+') || accDigits.startsWith('00');
      // After a country code, a group starting with 0 ("+44 20 7946 0000")
      // is still the same number; only + or 00 starts a new one.
      final bool startsNew = RegExp(
        international ? r'^(\+|00[1-9])' : r'^[+0]',
      ).hasMatch(p);
      // "+972 054…": a country code on its own, then the trunk zero.
      final bool countryCodeOnly =
          (acc.startsWith('+') && accDigits.length <= 3) ||
          (accDigits.startsWith('00') && accDigits.length <= 5);
      if (accDigits.length >= _expectedLength(acc)) {
        out.add(acc);
        acc = p;
      } else if (startsNew && !countryCodeOnly) {
        // A complete number ends here; a few stray digits are dropped.
        if (clean(acc).isNotEmpty) out.add(acc);
        acc = p;
      } else {
        acc = '$acc $p';
      }
    }
    if (acc.isNotEmpty) out.add(acc);
    return out;
  }

  /// How many digits a number that starts like [start] has in full.
  static int _expectedLength(String start) {
    final String s = start.trim();
    final String d = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (s.startsWith('+') || d.startsWith('00')) {
      final String cc = d.startsWith('00') ? d.substring(2) : d;
      return (cc.startsWith('972') ? 12 : 15) + (d.startsWith('00') ? 2 : 0);
    }
    if (d.startsWith('972')) return 12;
    if (RegExp(r'^0[57]').hasMatch(d)) return 10; // Israeli mobile, 07x VoIP
    if (RegExp(r'^0[2-489]').hasMatch(d)) return 9; // Israeli landline
    if (RegExp(r'^1[78]00').hasMatch(d)) return 10; // 1-800 / 1-700
    return 15;
  }

  /// 13.11.2026, 13/11/26, 2026-11-13: dates, not numbers to call.
  static bool _looksLikeDate(String run) =>
      RegExp(r'^\d{1,2}[./-]\d{1,2}[./-]\d{2}(\d{2})?$').hasMatch(run) ||
      RegExp(r'^\d{4}[./-]\d{1,2}[./-]\d{1,2}$').hasMatch(run);

  /// ASCII digits, plain dashes and spaces, and no direction marks.
  static String _plainText(String text) {
    final StringBuffer out = StringBuffer();
    for (final int c in text.runes) {
      if (c >= 0x0660 && c <= 0x0669) {
        out.writeCharCode(0x30 + c - 0x0660); // Arabic-Indic digits
      } else if (c >= 0x06F0 && c <= 0x06F9) {
        out.writeCharCode(0x30 + c - 0x06F0); // Extended Arabic-Indic
      } else if (c >= 0xFF10 && c <= 0xFF19) {
        out.writeCharCode(0x30 + c - 0xFF10); // full-width digits
      } else if (c == 0xFF0B) {
        out.write('+');
      } else if (c == 0x200E ||
          c == 0x200F ||
          c == 0x061C ||
          (c >= 0x202A && c <= 0x202E) ||
          (c >= 0x2066 && c <= 0x2069) ||
          c == 0x200B ||
          c == 0xFEFF) {
        // Direction marks and zero-width spaces: drop.
      } else if ((c >= 0x2010 && c <= 0x2015) || c == 0x2212) {
        out.write('-');
      } else if (c == 0x00A0 ||
          c == 0x2007 ||
          c == 0x2009 ||
          c == 0x202F ||
          c == 0x2002 ||
          c == 0x2003) {
        out.write(' ');
      } else if (c == 0x09) {
        out.write(' ');
      } else {
        out.writeCharCode(c);
      }
    }
    return out.toString();
  }
}
