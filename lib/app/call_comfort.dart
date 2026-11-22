import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

/// Which side the keypad leans to in one-handed mode (P17).
enum KeypadHand { both, left, right }

/// How strongly a key press buzzes (P17).
enum KeypadHaptics { off, light, strong }

/// How the dialer's keypad looks and feels, and the call comforts that
/// belong to this phone and the person holding it (P17, P29). Kept on this
/// phone only, like "Start calls with RTT": they don't follow the account.
class CallComfort {
  const CallComfort({
    this.largeKeys = false,
    this.hand = KeypadHand.both,
    this.keyTones = true,
    this.haptics = KeypadHaptics.light,
    this.flipToSilence = false,
    this.pocketGuard = false,
  });

  /// Bigger keys and digits.
  final bool largeKeys;

  /// One-handed mode: a narrower keypad on this side.
  final KeypadHand hand;

  /// A short tone for each key on the dialpad (not in calls, where the
  /// carrier tone is what you hear).
  final bool keyTones;
  final KeypadHaptics haptics;

  /// P29: turning a ringing phone face down silences it.
  final bool flipToSilence;

  /// P29: a call isn't placed while the screen is covered (a pocket or a
  /// bag), and the call screen ignores touches near the ear.
  final bool pocketGuard;

  CallComfort copyWith({
    bool? largeKeys,
    KeypadHand? hand,
    bool? keyTones,
    KeypadHaptics? haptics,
    bool? flipToSilence,
    bool? pocketGuard,
  }) => CallComfort(
    largeKeys: largeKeys ?? this.largeKeys,
    hand: hand ?? this.hand,
    keyTones: keyTones ?? this.keyTones,
    haptics: haptics ?? this.haptics,
    flipToSilence: flipToSilence ?? this.flipToSilence,
    pocketGuard: pocketGuard ?? this.pocketGuard,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'largeKeys': largeKeys,
    'hand': hand.name,
    'keyTones': keyTones,
    'haptics': haptics.name,
    'flipToSilence': flipToSilence,
    'pocketGuard': pocketGuard,
  };

  static CallComfort fromJson(Map<String, Object?> j) => CallComfort(
    largeKeys: j['largeKeys'] == true,
    hand: KeypadHand.values.firstWhere(
      (KeypadHand h) => h.name == j['hand'],
      orElse: () => KeypadHand.both,
    ),
    keyTones: j['keyTones'] != false,
    haptics: KeypadHaptics.values.firstWhere(
      (KeypadHaptics h) => h.name == j['haptics'],
      orElse: () => KeypadHaptics.light,
    ),
    flipToSilence: j['flipToSilence'] == true,
    pocketGuard: j['pocketGuard'] == true,
  );

  /// The buzz for one key press.
  void buzz() {
    switch (haptics) {
      case KeypadHaptics.off:
        break;
      case KeypadHaptics.light:
        HapticFeedback.selectionClick();
      case KeypadHaptics.strong:
        HapticFeedback.mediumImpact();
    }
  }
}

final callComfortProvider = NotifierProvider<CallComfortNotifier, CallComfort>(
  CallComfortNotifier.new,
);

class CallComfortNotifier extends Notifier<CallComfort> {
  static const String _key = 'call_comfort';

  /// Done once the saved choices are read.
  late Future<void> loaded;

  @override
  CallComfort build() {
    loaded = _load();
    return const CallComfort();
  }

  Future<void> _load() async {
    try {
      final String? raw = await ref.read(ztPreferencesStoreProvider).read(_key);
      if (raw != null) {
        state = CallComfort.fromJson(
          (jsonDecode(raw) as Map<Object?, Object?>).cast<String, Object?>(),
        );
      }
    } on Object {
      // A damaged value falls back to the defaults.
    }
    await _tellAndroid();
  }

  Future<void> set(CallComfort value) async {
    await loaded;
    state = value;
    await ref
        .read(ztPreferencesStoreProvider)
        .write(_key, jsonEncode(value.toJson()));
    await _tellAndroid();
  }

  /// Flip to silence works while the app is closed and the phone locked,
  /// so the Android side keeps its own copy of the two switches.
  Future<void> _tellAndroid() async {
    try {
      await ref
          .read(telecomProvider)
          .setCallComfort(
            flipToSilence: state.flipToSilence,
            pocketGuard: state.pocketGuard,
          );
    } on Object {
      // Tests, or an older Android side: nothing to tell.
    }
  }
}
