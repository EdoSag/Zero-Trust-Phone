import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/app/rtt_preference.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// Real-time text, TTY and carrier video calls (P12).
///
/// All three run over the carrier's network, between the phone and the
/// other person. ZT Phone doesn't route, see or keep any of it.
class CallAccessibilityPage extends ConsumerWidget {
  const CallAccessibilityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppL10n l = context.l10n;
    final bool startWithRtt = ref.watch(startWithRttProvider);
    final CallFeatures features =
        ref.watch(callFeaturesProvider).value ?? const CallFeatures();
    final Color muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: Text(l.callAccessibility)),
      body: ListView(
        children: <Widget>[
          SwitchListTile(
            secondary: const Icon(Icons.rtt),
            title: Text(l.startWithRtt),
            subtitle: Text(l.startWithRttBody),
            value: startWithRtt,
            onChanged: (bool on) =>
                ref.read(startWithRttProvider.notifier).set(on),
          ),
          ListTile(
            leading: Icon(
              features.rtt ? Icons.check_circle_outline : Icons.info_outline,
              color: muted,
            ),
            title: Text(features.rtt ? l.rttAvailable : l.rttNotAvailable),
            subtitle: features.rtt ? null : Text(l.rttNotAvailableBody),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: Text(l.videoCalling),
            subtitle: Text(
              features.video ? l.videoAvailable : l.videoNotAvailable,
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.hearing_outlined),
            title: Text(l.ttySettings),
            subtitle: Text(
              features.systemSettings
                  ? l.ttySettingsBody
                  : l.ttySettingsMissing,
            ),
            enabled: features.systemSettings,
            onTap: features.systemSettings
                ? () =>
                      ref.read(telecomProvider).openCallAccessibilitySettings()
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Text(
              l.callAccessibilityPrivacy,
              style: TextStyle(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
