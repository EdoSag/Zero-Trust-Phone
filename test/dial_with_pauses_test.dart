import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_phone/util/dial_sequence.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';

/// Dial with pauses (P15).
void main() {
  test('steps become the characters Android dials after the number', () {
    expect(
      DialSequence.encode(const <DialStep>[
        DialStep.pause(2),
        DialStep.tones('1234#'),
      ]),
      ',,1234#',
    );
    expect(
      DialSequence.encode(const <DialStep>[
        DialStep.wait(),
        DialStep.tones(' 98-76 *'),
      ]),
      ';9876*',
    );
  });

  test('a saved sequence reads back as the same steps', () {
    const List<DialStep> steps = <DialStep>[
      DialStep.pause(3),
      DialStep.tones('2'),
      DialStep.wait(),
      DialStep.tones('445566#'),
    ];
    expect(DialSequence.decode(DialSequence.encode(steps)), steps);
  });

  test('split separates the number from its pauses and tones', () {
    expect(DialSequence.split('03-1234567,,1234#'), ('03-1234567', ',,1234#'));
    expect(DialSequence.split('0541234567'), ('0541234567', ''));
    expect(DialSequence.hasPostDial('+972541234567;1#'), isTrue);
  });

  test('names still match a number dialled with tones after it', () {
    expect(PhoneNumbers.same('0541234567,,1234#', '+972 54-123-4567'), isTrue);
    expect(PhoneNumbers.lookupKey('*2700;5'), '2700');
  });
}
