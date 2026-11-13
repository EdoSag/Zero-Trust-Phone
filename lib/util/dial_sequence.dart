/// Dial with pauses (P15): phone menus, conference codes and voicemail
/// PINs as plain steps ("call, wait, then send 1234#"), turned into the
/// characters Android dials after the number:
///
/// - `,` a pause of about 3 seconds (Android's fixed pause length),
/// - `;` wait until I tap "Send" on the call screen,
/// - digits, `*` and `#` sent as tones.
enum DialStepKind { pause, wait, tones }

class DialStep {
  const DialStep.pause([this.count = 1])
    : kind = DialStepKind.pause,
      tones = '';
  const DialStep.wait() : kind = DialStepKind.wait, count = 1, tones = '';
  const DialStep.tones(this.tones) : kind = DialStepKind.tones, count = 1;

  final DialStepKind kind;

  /// Pauses in a row (each about 3 seconds).
  final int count;

  /// What a [DialStepKind.tones] step sends: digits, `*` and `#`.
  final String tones;

  @override
  bool operator ==(Object other) =>
      other is DialStep &&
      other.kind == kind &&
      other.count == count &&
      other.tones == tones;

  @override
  int get hashCode => Object.hash(kind, count, tones);

  @override
  String toString() => switch (kind) {
    DialStepKind.pause => 'pause×$count',
    DialStepKind.wait => 'wait',
    DialStepKind.tones => 'tones($tones)',
  };
}

abstract final class DialSequence {
  /// Seconds Android waits for each `,`.
  static const int pauseSeconds = 3;

  /// Only what a keypad can send as tones.
  static String cleanTones(String s) => s.replaceAll(RegExp(r'[^0-9*#]'), '');

  /// The characters for [steps], to put after the number.
  static String encode(List<DialStep> steps) {
    final StringBuffer out = StringBuffer();
    for (final DialStep s in steps) {
      switch (s.kind) {
        case DialStepKind.pause:
          out.write(',' * s.count.clamp(1, 20));
        case DialStepKind.wait:
          out.write(';');
        case DialStepKind.tones:
          out.write(cleanTones(s.tones));
      }
    }
    return out.toString();
  }

  /// [postDial] (what follows the number) as steps; runs of `,` become
  /// one pause step.
  static List<DialStep> decode(String postDial) {
    final List<DialStep> steps = <DialStep>[];
    final RegExp run = RegExp(r',+|;|[0-9*#]+');
    for (final RegExpMatch m in run.allMatches(postDial)) {
      final String t = m[0]!;
      if (t.startsWith(',')) {
        steps.add(DialStep.pause(t.length));
      } else if (t == ';') {
        steps.add(const DialStep.wait());
      } else {
        steps.add(DialStep.tones(t));
      }
    }
    return steps;
  }

  /// Splits a dial string ("0541234567,,1234#") into the number and what
  /// follows it (",,1234#").
  static (String number, String postDial) split(String dialString) {
    final int i = dialString.indexOf(RegExp('[,;]'));
    return i < 0
        ? (dialString, '')
        : (dialString.substring(0, i), dialString.substring(i));
  }

  static bool hasPostDial(String dialString) =>
      dialString.contains(RegExp('[,;]'));
}
