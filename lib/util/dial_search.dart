import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/util/countries.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';

/// How a contact matched what was typed on the dialpad, best first.
enum DialMatchKind {
  /// The name starts with it ("232" for Ada Lovelace), also when typed on
  /// past the first word.
  nameStart,

  /// Another word of the name starts with it ("568" Lovelace).
  nameWord,

  /// The first letters of the name's words ("25" for Ada Lovelace).
  initials,

  /// The company starts with it, or one of its words does.
  company,

  /// One of the contact's numbers contains it, in any spelling
  /// (+972 54..., 054..., 54...).
  number,
}

class DialMatch {
  const DialMatch(this.contact, this.kind, this.phones);

  final PhoneContact contact;
  final DialMatchKind kind;

  /// The numbers to offer: the ones that matched for a number match,
  /// otherwise all of the contact's numbers.
  final List<String> phones;
}

/// Smart dialpad search (P14): type digits and find contacts by name or
/// company, in English or Hebrew, or by any part of their number.
///
/// Letters sit on the keys as on Israeli phones: Latin 2 ABC ... 9 WXYZ,
/// and Hebrew 2 דהו, 3 אבג, 4 מנ, 5 יכל, 6 זחט, 7 רשת, 8 צק, 9 סעפ, with
/// final letters (ם ן ך ף ץ) on their usual letter's key. Vowel points,
/// accents and apostrophes ("צ'רלי", "O'Brien") are ignored.
abstract final class DialSearch {
  /// Hebrew letters per key, for the keypad's labels.
  static const Map<String, String> hebrewKeys = <String, String>{
    '2': 'דהו', '3': 'אבג', '4': 'מנ', '5': 'יכל', //
    '6': 'זחט', '7': 'רשת', '8': 'צק', '9': 'סעפ',
  };

  static const Map<String, String> _latinKeys = <String, String>{
    '2': 'abc', '3': 'def', '4': 'ghi', '5': 'jkl', //
    '6': 'mno', '7': 'pqrs', '8': 'tuv', '9': 'wxyz',
  };

  /// Final letters and accented Latin letters, as the letter they're typed as.
  static const Map<String, String> _fold = <String, String>{
    'ם': 'מ', 'ן': 'נ', 'ך': 'כ', 'ף': 'פ', 'ץ': 'צ', //
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y', 'ß': 's',
  };

  static final Map<String, String> _digitFor = <String, String>{
    for (final MapEntry<String, String> e in _latinKeys.entries)
      for (final String ch in e.value.split('')) ch: e.key,
    for (final MapEntry<String, String> e in hebrewKeys.entries)
      for (final String ch in e.value.split('')) ch: e.key,
  };

  /// Marks that join a word rather than split it: apostrophes, geresh and
  /// gershayim, plus Hebrew vowel points and cantillation (U+0591-U+05C7).
  static final RegExp _skip = RegExp('[\'’"׳״֑-ׇ]');

  /// [text] as dialpad digits, a space wherever a word breaks.
  static String encode(String text) {
    final StringBuffer out = StringBuffer();
    for (final String raw
        in text.toLowerCase().replaceAll(_skip, '').split('')) {
      final String ch = _fold[raw] ?? raw;
      final String? d = _digitFor[ch];
      if (d != null) {
        out.write(d);
      } else if (RegExp('[0-9]').hasMatch(ch)) {
        out.write(ch);
      } else {
        out.write(' ');
      }
    }
    return out.toString();
  }

  static List<String> _words(String encoded) => encoded
      .split(' ')
      .where((String w) => w.isNotEmpty)
      .toList(growable: false);

  /// How [text] (a name) matches [digits], or null.
  static DialMatchKind? matchName(String text, String digits) {
    if (digits.isEmpty) return null;
    final List<String> words = _words(encode(text));
    if (words.isEmpty) return null;
    if (words.first.startsWith(digits) || words.join().startsWith(digits)) {
      return DialMatchKind.nameStart;
    }
    for (int i = 1; i < words.length; i++) {
      // "Lovelace" alone, or "Lovelace" run on into a later word.
      if (words.skip(i).join().startsWith(digits)) {
        return DialMatchKind.nameWord;
      }
    }
    if (digits.length >= 2 && words.length >= 2) {
      final String initials = words.map((String w) => w[0]).join();
      if (initials.startsWith(digits)) return DialMatchKind.initials;
    }
    return null;
  }

  /// Whether a word of [company] starts with [digits].
  static bool matchCompany(String company, String digits) {
    if (digits.isEmpty || company.isEmpty) return false;
    final List<String> words = _words(encode(company));
    for (int i = 0; i < words.length; i++) {
      if (words.skip(i).join().startsWith(digits)) return true;
    }
    return false;
  }

  /// The digit strings someone might type for [number]: as stored, and for
  /// an international number also the national form with and without the
  /// leading 0 ("+972 54-123" -> "97254123", "054123", "54123").
  static List<String> numberForms(String number) {
    final String digits = PhoneNumbers.normalize(number).replaceAll('+', '');
    final List<String> forms = <String>[digits];
    final String trimmed = number.trim();
    String? intl;
    if (trimmed.startsWith('+')) {
      intl = digits;
    } else if (digits.startsWith('00')) {
      intl = digits.substring(2);
    }
    if (intl != null) {
      String? code;
      for (final Country c in countries) {
        if (intl.startsWith(c.code) &&
            (code == null || c.code.length > code.length)) {
          code = c.code;
        }
      }
      // +1 numbers have a 3-digit area code after "1", never a 0.
      if (intl.startsWith('1')) code = '1';
      if (code != null && intl.length > code.length) {
        final String national = intl.substring(code.length);
        forms.add(national);
        if (code != '1') forms.add('0$national');
      }
    }
    return forms;
  }

  /// Whether any spelling of [number] contains [digits].
  static bool matchNumber(String number, String digits) =>
      digits.isNotEmpty &&
      numberForms(number).any((String f) => f.contains(digits));

  /// Contacts for dialpad [digits], best matches first. A contact found by
  /// name and by number counts once, by its best match. Ties keep the
  /// contacts' own order.
  static List<DialMatch> search(
    List<PhoneContact> contacts,
    String digits, {
    int limit = 20,
  }) {
    if (digits.isEmpty) return const <DialMatch>[];
    final List<(int, DialMatch)> found = <(int, DialMatch)>[];
    for (int i = 0; i < contacts.length; i++) {
      final PhoneContact c = contacts[i];
      if (c.phones.isEmpty) continue;
      DialMatchKind? kind = matchName(c.name, digits);
      if (kind == null && matchCompany(c.company, digits)) {
        kind = DialMatchKind.company;
      }
      if (kind != null) {
        found.add((i, DialMatch(c, kind, c.phones)));
        continue;
      }
      final List<String> phones = c.phones
          .where((String p) => matchNumber(p, digits))
          .toList(growable: false);
      if (phones.isNotEmpty) {
        found.add((i, DialMatch(c, DialMatchKind.number, phones)));
      }
    }
    found.sort((a, b) {
      final int byKind = a.$2.kind.index.compareTo(b.$2.kind.index);
      return byKind != 0 ? byKind : a.$1.compareTo(b.$1);
    });
    return <DialMatch>[for (final (_, DialMatch m) in found.take(limit)) m];
  }
}
