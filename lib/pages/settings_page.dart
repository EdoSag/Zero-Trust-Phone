import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/app/history_retention.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/pages/blocked_numbers_page.dart';
import 'package:zerotrust_phone/pages/call_protection_page.dart';
import 'package:zerotrust_phone/pages/history_backup_page.dart';
import 'package:zerotrust_phone/pages/quick_replies_page.dart';
import 'package:zerotrust_phone/pages/speed_dial_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// The shared Zero-Trust settings screen, with Phone's own rows.
class PhoneSettingsPage extends ConsumerWidget {
  const PhoneSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDefault = ref.watch(defaultDialerProvider).value ?? false;
    final int? keepDays = ref.watch(historyRetentionProvider);
    final CallProtection protection = ref.watch(callProtectionProvider);
    final int contactCount =
        ref.watch(phoneContactsProvider).value?.length ?? 0;

    void push(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));

    return ZtSettingsPage(
      showSyncStatus: false,
      onSignedOut: () =>
          Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst),
      onOpenUrl: (Uri url) =>
          launchUrl(url, mode: LaunchMode.externalApplication),
      appSection: <Widget>[
        ListTile(
          leading: const Icon(Icons.phone_android_outlined),
          title: Text(context.l10n.defaultPhoneApp),
          subtitle: Text(
            isDefault
                ? context.l10n.defaultPhoneAppOn
                : context.l10n.defaultPhoneAppOff,
          ),
          onTap: isDefault
              ? null
              : () async {
                  final Telecom telecom = ref.read(telecomProvider);
                  if (await telecom.requestDefaultDialer()) {
                    await telecom.requestPermissions();
                  }
                  ref.invalidate(defaultDialerProvider);
                },
        ),
        ListTile(
          leading: const Icon(Icons.contacts_outlined),
          title: Text(context.l10n.namesFromContacts),
          subtitle: Text(context.l10n.namesFromContactsBody(contactCount)),
          onTap: () async {
            final ContactsMirror? mirror = ref
                .read(contactsMirrorProvider)
                .value;
            await mirror?.refresh();
          },
        ),
        ListTile(
          leading: const Icon(Icons.auto_delete_outlined),
          title: Text(context.l10n.keepCallHistory),
          subtitle: Text(HistoryRetention.label(keepDays)),
          onTap: () => _pickRetention(context, ref, keepDays),
        ),
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: Text(context.l10n.callProtection),
          subtitle: Text(_protectionSummary(protection)),
          onTap: () => push(const CallProtectionPage()),
        ),
        ListTile(
          leading: const Icon(Icons.block),
          title: Text(context.l10n.blockedNumbers),
          onTap: () => push(const BlockedNumbersPage()),
        ),
        ListTile(
          leading: const Icon(Icons.message_outlined),
          title: Text(context.l10n.quickReplies),
          subtitle: Text(context.l10n.quickRepliesBody),
          onTap: () => push(const QuickRepliesPage()),
        ),
        ListTile(
          leading: const Icon(Icons.speed),
          title: Text(context.l10n.speedDial),
          subtitle: Text(context.l10n.speedDialBody),
          onTap: () => push(const SpeedDialPage()),
        ),
        ListTile(
          leading: const Icon(Icons.voicemail),
          title: Text(context.l10n.voicemail),
          subtitle: Text(context.l10n.voicemailBody),
          onTap: () => ref.read(telecomProvider).voicemailSettings(),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_sync_outlined),
          title: Text(context.l10n.callHistoryBackup),
          subtitle: Text(
            protection.backupHistory ? context.l10n.backupOn : context.l10n.off,
          ),
          onTap: () => push(const HistoryBackupPage()),
        ),
        ListTile(
          leading: const Icon(Icons.do_not_disturb_on_outlined),
          title: Text(context.l10n.dndStarred),
          subtitle: Text(context.l10n.dndStarredBody),
        ),
      ],
    );
  }

  static String _protectionSummary(CallProtection p) {
    final AppL10n l = currentL10n;
    final List<String> parts = <String>[
      if (p.unknownCallers != UnknownCallers.ring)
        p.unknownCallers == UnknownCallers.silence
            ? l.unknownSilenced
            : l.unknownToVoicemail,
      if (p.blockHidden) l.hiddenBlocked,
      if (p.blockedPrefixes.isNotEmpty)
        l.prefixesBlocked(p.blockedPrefixes.length),
    ];
    if (parts.isEmpty) {
      return l.protectionOff;
    }
    final String s = parts.join(', ');
    return s[0].toUpperCase() + s.substring(1);
  }

  Future<void> _pickRetention(
    BuildContext context,
    WidgetRef ref,
    int? current,
  ) async {
    final int? picked = await showDialog<int>(
      context: context,
      builder: (BuildContext d) => SimpleDialog(
        title: Text(d.l10n.keepCallHistory),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(d.l10n.retentionBody),
          ),
          RadioGroup<int>(
            groupValue: current ?? 0,
            onChanged: (int? v) => Navigator.of(d).pop(v),
            child: Column(
              children: <Widget>[
                for (final int? days in HistoryRetention.choices)
                  RadioListTile<int>(
                    value: days ?? 0,
                    title: Text(HistoryRetention.label(days)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    await ref
        .read(historyRetentionProvider.notifier)
        .set(picked == 0 ? null : picked);
  }
}
