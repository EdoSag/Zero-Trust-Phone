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
          title: const Text('Default Phone app'),
          subtitle: Text(
            isDefault
                ? 'ZT Phone handles your calls'
                : 'Another app handles calls. Tap to switch to ZT Phone',
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
          title: const Text('Names from ZT Contacts'),
          subtitle: Text(
            '$contactCount '
            '${contactCount == 1 ? 'contact' : 'contacts'}, encrypted on '
            'this phone. Edit them in ZT Contacts',
          ),
          onTap: () async {
            final ContactsMirror? mirror = ref
                .read(contactsMirrorProvider)
                .value;
            await mirror?.refresh();
          },
        ),
        ListTile(
          leading: const Icon(Icons.auto_delete_outlined),
          title: const Text('Keep call history'),
          subtitle: Text(HistoryRetention.label(keepDays)),
          onTap: () => _pickRetention(context, ref, keepDays),
        ),
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: const Text('Call protection'),
          subtitle: Text(_protectionSummary(protection)),
          onTap: () => push(const CallProtectionPage()),
        ),
        ListTile(
          leading: const Icon(Icons.block),
          title: const Text('Blocked numbers'),
          onTap: () => push(const BlockedNumbersPage()),
        ),
        ListTile(
          leading: const Icon(Icons.message_outlined),
          title: const Text('Quick replies'),
          subtitle: const Text('Texts to send when you decline a call'),
          onTap: () => push(const QuickRepliesPage()),
        ),
        ListTile(
          leading: const Icon(Icons.speed),
          title: const Text('Speed dial'),
          subtitle: const Text('Hold 2 to 9 on the dialpad'),
          onTap: () => push(const SpeedDialPage()),
        ),
        ListTile(
          leading: const Icon(Icons.voicemail),
          title: const Text('Voicemail'),
          subtitle: const Text(
            'Hold 1 on the dialpad to call it. Tap for '
            'your carrier\'s voicemail settings',
          ),
          onTap: () => ref.read(telecomProvider).voicemailSettings(),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_sync_outlined),
          title: const Text('Call history backup'),
          subtitle: Text(
            protection.backupHistory ? 'On, end-to-end encrypted' : 'Off',
          ),
          onTap: () => push(const HistoryBackupPage()),
        ),
        const ListTile(
          leading: Icon(Icons.do_not_disturb_on_outlined),
          title: Text('Do Not Disturb and starred contacts'),
          subtitle: Text(
            'Android lets starred contacts through Do Not Disturb only if '
            'it can see them. Turn on "Show in Phone and Messages" in ZT '
            'Contacts settings for that.',
          ),
        ),
      ],
    );
  }

  static String _protectionSummary(CallProtection p) {
    final List<String> parts = <String>[
      if (p.unknownCallers != UnknownCallers.ring)
        p.unknownCallers == UnknownCallers.silence
            ? 'Unknown callers silenced'
            : 'Unknown callers to voicemail',
      if (p.blockHidden) 'hidden numbers blocked',
      if (p.blockedPrefixes.isNotEmpty)
        '${p.blockedPrefixes.length} blocked '
            '${p.blockedPrefixes.length == 1 ? 'prefix' : 'prefixes'}',
    ];
    if (parts.isEmpty) {
      return 'Off. Silence unknown callers, block hidden numbers or prefixes';
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
        title: const Text('Keep call history'),
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Older calls are deleted from this phone\'s call '
              'history, also for other apps.',
            ),
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
