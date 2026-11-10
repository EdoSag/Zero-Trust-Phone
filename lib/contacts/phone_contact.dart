import 'package:zerotrust_phone/util/phone_numbers.dart';

/// What the dialer needs of a ZT Contacts contact. Read from the encrypted
/// Contacts items; Phone never writes them.
class PhoneContact {
  const PhoneContact({
    required this.id,
    required this.name,
    required this.phones,
    this.company = '',
    this.isFavorite = false,
    this.isBlocked = false,
  });

  final String id;
  final String name;
  final List<String> phones;
  final String company;
  final bool isFavorite;
  final bool isBlocked;

  /// A contact item's JSON (Contacts `VaultContact.toJson`), or null when it
  /// isn't a live contact. Tolerant of fields newer Contacts versions add.
  static PhoneContact? fromItem(String id, Map<String, Object?>? json) {
    if (json == null || json['kind'] != 'contact') return null;
    String str(Object? v) => v is String ? v.trim() : '';
    final List<String> phones = <String>[
      for (final Object? p in (json['phones'] as List<Object?>?) ?? <Object?>[])
        if (p is String && p.trim().isNotEmpty) p.trim(),
    ];
    String name = str(json['displayName']);
    if (name.isEmpty) {
      name = '${str(json['firstName'])} ${str(json['lastName'])}'.trim();
    }
    if (name.isEmpty) name = str(json['company']);
    if (name.isEmpty && phones.isNotEmpty) name = phones.first;
    if (name.isEmpty) return null;
    return PhoneContact(
      id: id,
      name: name,
      phones: phones,
      company: str(json['company']),
      isFavorite: json['isFavorite'] == true,
      isBlocked: json['isBlocked'] == true,
    );
  }

  bool matches(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (name.toLowerCase().contains(q) || company.toLowerCase().contains(q)) {
      return true;
    }
    final String digits = q.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 3 &&
        phones.any((String p) => PhoneNumbers.normalize(p).contains(digits));
  }
}

/// Names by number, for calls and the call history.
class ContactDirectory {
  ContactDirectory(this.contacts) {
    for (final PhoneContact c in contacts) {
      for (final String p in c.phones) {
        final String key = PhoneNumbers.lookupKey(p);
        if (key.isNotEmpty) _byKey.putIfAbsent(key, () => c);
      }
    }
  }

  static final ContactDirectory empty = ContactDirectory(const []);

  final List<PhoneContact> contacts;
  final Map<String, PhoneContact> _byKey = <String, PhoneContact>{};

  PhoneContact? lookup(String number) => _byKey[PhoneNumbers.lookupKey(number)];

  /// Lookup key to name, handed to the in-call screen while unlocked.
  Map<String, String> get namesByKey => <String, String>{
    for (final MapEntry<String, PhoneContact> e in _byKey.entries)
      e.key: e.value.name,
  };
}
