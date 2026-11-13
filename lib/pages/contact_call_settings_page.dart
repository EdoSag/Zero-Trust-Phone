import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

final phoneAccountsProvider = FutureProvider<List<PhoneAccount>>(
  (ref) => ref.watch(telecomProvider).phoneAccounts(),
);

/// A contact's own ringtone, "always send to voicemail" (P7) and the SIM
/// to call them with (P6). Encrypted in the account like all Phone data.
class ContactCallSettingsPage extends ConsumerWidget {
  const ContactCallSettingsPage({super.key, required this.contact});

  final PhoneContact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ContactCallSettings settings =
        (ref.watch(contactSettingsProvider).value ??
                const <ContactCallSettings>[])
            .where((ContactCallSettings s) => s.contactId == contact.id)
            .firstOrNull ??
        ContactCallSettings(contactId: contact.id);
    final List<PhoneAccount> accounts =
        ref.watch(phoneAccountsProvider).value ?? const <PhoneAccount>[];
    final PhoneData data = ref.read(phoneDataProvider);

    return Scaffold(
      appBar: AppBar(title: Text(contact.name)),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.music_note_outlined),
            title: Text(context.l10n.ringtone),
            subtitle: Text(
              settings.ringtone == null
                  ? context.l10n.phoneRingtone
                  : (settings.ringtoneTitle ?? context.l10n.custom),
            ),
            onTap: () async {
              final Telecom telecom = ref.read(telecomProvider);
              final String? picked = await telecom.pickRingtone(
                current: settings.ringtone,
              );
              if (picked == null) return; // Cancelled.
              final String? title = picked.isEmpty
                  ? null
                  : await telecom.ringtoneTitle(picked);
              await data.saveContactSettings(
                settings.copyWith(
                  ringtone: () => picked.isEmpty ? null : picked,
                  ringtoneTitle: () => title,
                ),
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.voicemail),
            title: Text(context.l10n.sendToVoicemail),
            subtitle: Text(context.l10n.sendToVoicemailBody),
            value: settings.toVoicemail,
            onChanged: (bool on) =>
                data.saveContactSettings(settings.copyWith(toVoicemail: on)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: Text(context.l10n.hideMyNumberForContact),
            subtitle: Text(context.l10n.hideMyNumberForContactBody),
            value: settings.hideCallerId,
            onChanged: (bool on) =>
                data.saveContactSettings(settings.copyWith(hideCallerId: on)),
          ),
          if (accounts.length > 1)
            ListTile(
              leading: const Icon(Icons.sim_card_outlined),
              title: Text(context.l10n.callWith),
              subtitle: Text(
                settings.accountLabel ?? context.l10n.askOrDefault,
              ),
              onTap: () => _pickSim(context, data, settings, accounts),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.callSettingsExplain),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSim(
    BuildContext context,
    PhoneData data,
    ContactCallSettings settings,
    List<PhoneAccount> accounts,
  ) async {
    final PhoneAccount? picked = await showDialog<PhoneAccount?>(
      context: context,
      builder: (BuildContext d) => SimpleDialog(
        title: Text(d.l10n.callWith),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(d).pop(const PhoneAccount(id: '', label: '')),
            child: Text(d.l10n.askOrDefault),
          ),
          for (final PhoneAccount a in accounts)
            SimpleDialogOption(
              onPressed: () => Navigator.of(d).pop(a),
              child: Text(a.label),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await data.saveContactSettings(
      settings.copyWith(
        accountId: () => picked.id.isEmpty ? null : picked.id,
        accountLabel: () => picked.id.isEmpty ? null : picked.label,
      ),
    );
  }
}
