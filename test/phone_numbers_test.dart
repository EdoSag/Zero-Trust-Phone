import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/pages/recents_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';

void main() {
  test('international and local spellings of a number match', () {
    expect(PhoneNumbers.same('+44 7700 900123', '07700 900123'), isTrue);
    expect(PhoneNumbers.same('+1 (415) 555-0100', '415-555-0100'), isTrue);
    expect(PhoneNumbers.same('112', '112'), isTrue);
    expect(PhoneNumbers.same('07700 900123', '07700 900124'), isFalse);
    expect(PhoneNumbers.same('', ''), isFalse);
  });

  test('T9 finds names by the dialpad digits of any word', () {
    expect(PhoneNumbers.t9Matches('Ada Lovelace', '232'), isTrue); // Ada
    expect(PhoneNumbers.t9Matches('Ada Lovelace', '568'), isTrue); // Lov
    expect(PhoneNumbers.t9Matches('Ada Lovelace', '999'), isFalse);
    expect(PhoneNumbers.t9Matches('Ada', ''), isFalse);
  });

  test('contacts are read from ZT Contacts item JSON', () {
    final PhoneContact? c = PhoneContact.fromItem('id1', <String, Object?>{
      'kind': 'contact',
      '_v': 1,
      'displayName': '',
      'firstName': 'Grace',
      'lastName': 'Hopper',
      'phones': <Object?>['+1 202 555 0100', '  '],
      'isFavorite': true,
      'someFutureField': 42,
    });
    expect(c, isNotNull);
    expect(c!.name, 'Grace Hopper');
    expect(c.phones, <String>['+1 202 555 0100']);
    expect(c.isFavorite, isTrue);
    expect(c.matches('hop'), isTrue);
    expect(c.matches('5550100'), isTrue);

    // Trashed contacts and other kinds are not contacts.
    expect(
      PhoneContact.fromItem('id2', <String, Object?>{
        'kind': 'contact_trash',
        'displayName': 'Gone',
      }),
      isNull,
    );
    expect(PhoneContact.fromItem('id3', null), isNull);
  });

  test('the directory names a call by any spelling of the number', () {
    final ContactDirectory dir = ContactDirectory(const <PhoneContact>[
      PhoneContact(id: 'a', name: 'Alan', phones: <String>['+44 7700 900123']),
    ]);
    expect(dir.lookup('07700900123')?.name, 'Alan');
    expect(dir.lookup('07700900999'), isNull);
    expect(dir.namesByKey, <String, String>{'700900123': 'Alan'});
  });

  test('back-to-back calls with one number on one day are one row', () {
    CallLogEntry call(int id, String n, DateTime d) => CallLogEntry(
      id: id,
      number: n,
      type: CallType.missed,
      date: d,
      duration: Duration.zero,
    );
    final List<CallGroup> groups = CallGroup.group(<CallLogEntry>[
      call(1, '07700 900123', DateTime(2026, 11, 9, 12)),
      call(2, '+447700900123', DateTime(2026, 11, 9, 11)),
      call(3, '07700 900999', DateTime(2026, 11, 9, 10)),
      call(4, '07700 900999', DateTime(2026, 11, 8, 10)),
    ]);
    expect(groups.map((CallGroup g) => g.calls.length), <int>[2, 1, 1]);
  });

  test('day labels', () {
    final DateTime now = DateTime(2026, 11, 9, 15);
    expect(dayLabel(DateTime(2026, 11, 9, 1), now), 'Today');
    expect(dayLabel(DateTime(2026, 11, 8, 23), now), 'Yesterday');
    expect(dayLabel(DateTime(2026, 3, 2), now), '2 Mar');
    expect(dayLabel(DateTime(2025, 3, 2), now), '2 Mar 2025');
  });
}
