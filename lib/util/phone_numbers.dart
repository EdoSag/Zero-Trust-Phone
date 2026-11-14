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
  /// Pauses and tones dialled after the number (",,1234#", P15) aren't
  /// part of it. Must stay the same as `PhoneNumbers.lookupKey` in the
  /// Android code.
  static String lookupKey(String number) {
    final int post = number.indexOf(RegExp('[,;]'));
    final String digits = (post < 0 ? number : number.substring(0, post))
        .replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 9 ? digits.substring(digits.length - 9) : digits;
  }

  static bool same(String a, String b) {
    final String ka = lookupKey(a);
    return ka.isNotEmpty && ka == lookupKey(b);
  }
}
