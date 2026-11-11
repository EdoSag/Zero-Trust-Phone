/// Real-time text (RTT, P12): what both sides typed during a call.
///
/// RTT sends each letter the moment it's typed. "\b" erases the letter
/// before it and "\n" ends a line, so the conversation reads like a chat
/// whose last bubbles are still being typed. Nothing here is saved: the
/// transcript lives only while the call screen is open.
library;

class RttMessage {
  RttMessage({required this.fromMe, this.text = '', this.done = false});

  final bool fromMe;
  String text;

  /// False while the other person is still typing this line.
  bool done;
}

class RttTranscript {
  final List<RttMessage> messages = <RttMessage>[];

  /// What the other person already sees of the line being typed here.
  String _sent = '';

  /// The line being typed here, so a rebuilt text field can show it again.
  String get draft => _sent;

  /// The other person's line being typed, if any.
  RttMessage? get _open {
    for (final RttMessage m in messages.reversed) {
      if (!m.fromMe) return m.done ? null : m;
    }
    return null;
  }

  /// Adds text from the other person.
  void receive(String chunk) {
    for (final int rune in chunk.runes) {
      switch (rune) {
        case 0x08: // Backspace.
          final RttMessage? open = _open;
          if (open != null && open.text.isNotEmpty) {
            final List<int> runes = open.text.runes.toList()..removeLast();
            open.text = String.fromCharCodes(runes);
          }
        case 0x0A: // New line: their line is finished.
        case 0x2028:
          final RttMessage? open = _open;
          if (open != null) {
            open.done = true;
            if (open.text.isEmpty) messages.remove(open);
          }
        case 0x0D:
        case 0xFEFF:
          break; // "\r" of "\r\n", and the T.140 zero-width start mark.
        default:
          (_open ?? _newRemote()).text += String.fromCharCode(rune);
      }
    }
  }

  RttMessage _newRemote() {
    final RttMessage m = RttMessage(fromMe: false);
    messages.add(m);
    return m;
  }

  /// The text field now holds [draft]: returns what to send so the other
  /// person sees the same.
  String typed(String draft) {
    final String delta = rttDelta(_sent, draft);
    _sent = draft;
    return delta;
  }

  /// Finishes the line being typed. Returns what to send ("" if nothing).
  String submit() {
    if (_sent.trim().isEmpty) return '';
    messages.add(RttMessage(fromMe: true, text: _sent, done: true));
    _sent = '';
    return '\n';
  }
}

/// What turns [from] into [to] on the other person's screen: a backspace
/// for each letter after the common start, then the new letters.
String rttDelta(String from, String to) {
  final List<int> a = from.runes.toList();
  final List<int> b = to.runes.toList();
  int same = 0;
  while (same < a.length && same < b.length && a[same] == b[same]) {
    same++;
  }
  return '\b' * (a.length - same) + String.fromCharCodes(b.skip(same));
}
