import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/services/screening_sync.dart';

void main() {
  const List<PhoneContact> contacts = <PhoneContact>[
    PhoneContact(id: 'ada', name: 'Ada', phones: <String>['+44 7700 900123']),
    PhoneContact(id: 'bob', name: 'Bob', phones: <String>['07700 900456']),
    PhoneContact(
      id: 'eve',
      name: 'Eve',
      phones: <String>['+1 202 555 0199'],
      isBlocked: true,
    ),
  ];

  ScreeningRules rules(CallProtection p) => ScreeningRules.build(
    contacts: contacts,
    settings: const <ContactCallSettings>[
      ContactCallSettings(contactId: 'bob', toVoicemail: true),
      ContactCallSettings(contactId: 'ada', ringtone: 'content://tone/1'),
    ],
    protection: p,
  );

  test('contacts ring; unknown callers follow the setting', () {
    final ScreeningRules ring = rules(const CallProtection());
    expect(decideCall(ring, number: '07700900123'), ScreeningDecision.allow);
    expect(decideCall(ring, number: '+3312345678'), ScreeningDecision.allow);

    final ScreeningRules silence = rules(
      const CallProtection(unknownCallers: UnknownCallers.silence),
    );
    expect(
      decideCall(silence, number: '+3312345678'),
      ScreeningDecision.silence,
    );
    expect(decideCall(silence, number: '07700900123'), ScreeningDecision.allow);

    final ScreeningRules vm = rules(
      const CallProtection(unknownCallers: UnknownCallers.voicemail),
    );
    expect(decideCall(vm, number: '+3312345678'), ScreeningDecision.voicemail);
  });

  test('per-contact voicemail, and contacts blocked in ZT Contacts', () {
    final ScreeningRules r = rules(const CallProtection());
    expect(decideCall(r, number: '+447700900456'), ScreeningDecision.voicemail);
    expect(decideCall(r, number: '2025550199'), ScreeningDecision.voicemail);
    expect(r.ringtones.values, <String>['content://tone/1']);
  });

  test('hidden numbers and prefixes', () {
    final ScreeningRules r = rules(
      const CallProtection(
        blockHidden: true,
        blockedPrefixes: <String>['+1900', '+44'],
      ),
    );
    expect(decideCall(r, number: '', hidden: true), ScreeningDecision.block);
    expect(decideCall(r, number: '+19005551234'), ScreeningDecision.block);
    expect(decideCall(r, number: '00441234567'), ScreeningDecision.block);
    expect(decideCall(r, number: '+3312345678'), ScreeningDecision.allow);

    final ScreeningRules open = rules(const CallProtection());
    expect(decideCall(open, number: '', hidden: true), ScreeningDecision.allow);
  });

  test('prefix matching', () {
    expect(prefixMatches('+44 20 7946 0000', '+44'), isTrue);
    expect(prefixMatches('0044 20 7946 0000', '+44'), isTrue);
    expect(prefixMatches('+33 1 23 45 67 89', '+44'), isFalse);
    expect(prefixMatches('0870 123 456', '0870'), isTrue);
    expect(prefixMatches('123', ''), isFalse);
  });

  test('same() spots changes', () {
    final ScreeningRules a = rules(const CallProtection());
    expect(a.same(rules(const CallProtection())), isTrue);
    expect(a.same(rules(const CallProtection(blockHidden: true))), isFalse);
  });
}
