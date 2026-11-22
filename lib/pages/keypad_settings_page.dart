import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/app/call_comfort.dart';
import 'package:zerotrust_phone/pages/dialpad_page.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// Settings > Keypad and handling: keypad size, one-handed mode, key tones
/// and buzz (P17), flip to silence and the pocket guard (P29). Kept on this
/// phone only.
class KeypadSettingsPage extends ConsumerWidget {
  const KeypadSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppL10n l = context.l10n;
    final CallComfort c = ref.watch(callComfortProvider);
    void set(CallComfort next) =>
        ref.read(callComfortProvider.notifier).set(next);
    final TextStyle? header = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: Theme.of(context).colorScheme.primary,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.keypadAndHandling)),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(l.keypad, style: header),
          ),
          SwitchListTile(
            key: const ValueKey<String>('large-keys'),
            secondary: const Icon(Icons.text_increase),
            title: Text(l.largeKeys),
            subtitle: Text(l.largeKeysBody),
            value: c.largeKeys,
            onChanged: (bool on) => set(c.copyWith(largeKeys: on)),
          ),
          ListTile(
            leading: const Icon(Icons.back_hand_outlined),
            title: Text(l.oneHandedMode),
            subtitle: Text(l.oneHandedModeBody),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<KeypadHand>(
              key: const ValueKey<String>('hand'),
              segments: <ButtonSegment<KeypadHand>>[
                ButtonSegment<KeypadHand>(
                  value: KeypadHand.left,
                  label: Text(l.handLeft),
                ),
                ButtonSegment<KeypadHand>(
                  value: KeypadHand.both,
                  label: Text(l.off),
                ),
                ButtonSegment<KeypadHand>(
                  value: KeypadHand.right,
                  label: Text(l.handRight),
                ),
              ],
              selected: <KeypadHand>{c.hand},
              onSelectionChanged: (Set<KeypadHand> s) =>
                  set(c.copyWith(hand: s.first)),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const ValueKey<String>('key-tones'),
            secondary: const Icon(Icons.music_note_outlined),
            title: Text(l.keyTones),
            subtitle: Text(l.keyTonesBody),
            value: c.keyTones,
            onChanged: (bool on) => set(c.copyWith(keyTones: on)),
          ),
          ListTile(
            leading: const Icon(Icons.vibration),
            title: Text(l.keyVibration),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<KeypadHaptics>(
              segments: <ButtonSegment<KeypadHaptics>>[
                ButtonSegment<KeypadHaptics>(
                  value: KeypadHaptics.off,
                  label: Text(l.off),
                ),
                ButtonSegment<KeypadHaptics>(
                  value: KeypadHaptics.light,
                  label: Text(l.vibrationLight),
                ),
                ButtonSegment<KeypadHaptics>(
                  value: KeypadHaptics.strong,
                  label: Text(l.vibrationStrong),
                ),
              ],
              selected: <KeypadHaptics>{c.haptics},
              onSelectionChanged: (Set<KeypadHaptics> s) {
                final CallComfort next = c.copyWith(haptics: s.first);
                next.buzz();
                set(next);
              },
            ),
          ),
          const SizedBox(height: 8),
          // A preview, so the size and side can be tried at once.
          IgnorePointer(
            child: Opacity(
              opacity: 0.8,
              child: DialKeypad(
                onKey: (_) {},
                large: c.largeKeys,
                hand: c.hand,
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(l.handling, style: header),
          ),
          SwitchListTile(
            key: const ValueKey<String>('flip-to-silence'),
            secondary: const Icon(Icons.screen_rotation_alt_outlined),
            title: Text(l.flipToSilence),
            subtitle: Text(l.flipToSilenceBody),
            value: c.flipToSilence,
            onChanged: (bool on) => set(c.copyWith(flipToSilence: on)),
          ),
          SwitchListTile(
            key: const ValueKey<String>('pocket-guard'),
            secondary: const Icon(Icons.do_not_touch_outlined),
            title: Text(l.pocketGuard),
            subtitle: Text(l.pocketGuardBody),
            value: c.pocketGuard,
            onChanged: (bool on) => set(c.copyWith(pocketGuard: on)),
          ),
        ],
      ),
    );
  }
}
