/// Matching and formatting of phone numbers, without a numbering-plan
/// database: good enough to put names on calls and to search.
abstract final class PhoneNumbers {
  /// Digits only, keeping a leading `+`.
  static String normalize(String number) {
    final String trimmed = number.trim();
    final String digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return trimmed.startsWith('+') ? '+$digits' : digits;
  }

  /// The key two spellings of one number share: its last 9 digits, so
  /// "+44 7700 900123" and "07700 900123" match. Short codes match whole.
  /// Must stay the same as `PhoneNumbers.lookupKey` in the Android code.
  static String lookupKey(String number) {
    final String digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 9 ? digits.substring(digits.length - 9) : digits;
  }

  static bool same(String a, String b) {
    final String ka = lookupKey(a);
    return ka.isNotEmpty && ka == lookupKey(b);
  }

  /// The dialpad digit for each letter (2 = ABC ... 9 = WXYZ).
  static const Map<String, String> _t9 = <String, String>{
    'a': '2', 'b': '2', 'c': '2', 'd': '3', 'e': '3', 'f': '3', //
    'g': '4', 'h': '4', 'i': '4', 'j': '5', 'k': '5', 'l': '5',
    'm': '6', 'n': '6', 'o': '6', 'p': '7', 'q': '7', 'r': '7', 's': '7',
    't': '8', 'u': '8', 'v': '8', 'w': '9', 'x': '9', 'y': '9', 'z': '9',
  };

  /// [name] as dialpad digits, for search by typing on the dialpad.
  static String t9(String name) {
    final StringBuffer out = StringBuffer();
    for (final String ch in name.toLowerCase().split('')) {
      final String? d = _t9[ch];
      if (d != null) {
        out.write(d);
      } else if (RegExp(r'[0-9]').hasMatch(ch)) {
        out.write(ch);
      } else {
        out.write(' ');
      }
    }
    return out.toString();
  }

  /// Whether dialpad [digits] match the start of any word of [name] (T9).
  static bool t9Matches(String name, String digits) {
    if (digits.isEmpty) return false;
    final String encoded = t9(name);
    if (encoded.replaceAll(' ', '').startsWith(digits)) return true;
    return encoded.split(' ').any((String w) => w.startsWith(digits));
  }
}
