import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_phone/call/rtt.dart';

void main() {
  test('their typing arrives letter by letter, with erasing', () {
    final RttTranscript t = RttTranscript();
    t.receive('Hel');
    t.receive('lpp');
    t.receive('\b\bo there');
    expect(t.messages.single.text, 'Hello there');
    expect(t.messages.single.done, isFalse);
    t.receive('\r\n');
    expect(t.messages.single.done, isTrue);
    // A new line starts a new bubble; erasing can't reach the old one.
    t.receive('\b\bOK');
    expect(t.messages.map((m) => m.text), <String>['Hello there', 'OK']);
  });

  test('what we type is sent as a running difference', () {
    final RttTranscript t = RttTranscript();
    expect(t.typed('Hi'), 'Hi');
    expect(t.typed('Hi!'), '!');
    expect(t.typed('Hey'), '\b\bey');
    expect(t.typed(''), '\b\b\b');
    expect(t.typed('שלום'), 'שלום');
    expect(t.submit(), '\n');
    expect(t.messages.single.fromMe, isTrue);
    expect(t.messages.single.text, 'שלום');
    expect(t.submit(), '', reason: 'nothing typed, nothing sent');
  });

  test('emoji are erased whole', () {
    expect(rttDelta('ok 👍', 'ok '), '\b');
    final RttTranscript t = RttTranscript()..receive('a👍\b');
    expect(t.messages.single.text, 'a');
  });

  test('their line and ours interleave like a chat', () {
    final RttTranscript t = RttTranscript();
    t.receive('Can you hear');
    t.typed('Yes');
    t.submit();
    t.receive(' me?\n');
    expect(t.messages.map((m) => (m.fromMe, m.text)), <(bool, String)>[
      (false, 'Can you hear me?'),
      (true, 'Yes'),
    ]);
  });
}
