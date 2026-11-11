import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerotrust_phone/app/rtt_preference.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/pages/call_details_page.dart';
import 'package:zerotrust_phone/pages/contact_call_settings_page.dart';
import 'package:zerotrust_phone/pages/dialpad_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// Calls [number], on the contact's own SIM when one is set (P6), with
/// real-time text when that's switched on (P12). [video] makes it a
/// carrier video call.
Future<void> placeCall(
  WidgetRef ref,
  String number, {
  bool video = false,
}) async {
  final PhoneContact? contact = ref
      .read(contactDirectoryProvider)
      .lookup(number);
  String? account;
  if (contact != null) {
    for (final ContactCallSettings s
        in ref.read(contactSettingsProvider).value ??
            const <ContactCallSettings>[]) {
      if (s.contactId == contact.id) account = s.accountId;
    }
  }
  final StartWithRtt rtt = ref.read(startWithRttProvider.notifier);
  await rtt.loaded;
  final Telecom telecom = ref.read(telecomProvider);
  // Without the camera the call still goes out, showing only their video.
  if (video) await telecom.requestCamera();
  await telecom.placeCall(
    number,
    account: account,
    rtt: ref.read(startWithRttProvider),
    video: video,
  );
}

Future<void> sendMessage(String number) =>
    launchUrl(Uri(scheme: 'smsto', path: number));

/// A contact or number: call, copy, edit before calling, block.
Future<void> showNumberSheet(
  BuildContext context,
  WidgetRef ref, {
  required String number,
  PhoneContact? contact,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (BuildContext sheet) {
    final String title = contact?.name ?? number;
    final List<String> numbers = contact != null && contact.phones.isNotEmpty
        ? contact.phones
        : <String>[number];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          ListTile(
            leading: ContactAvatar(label: contact?.name ?? '', radius: 24),
            title: Text(title, style: Theme.of(sheet).textTheme.titleLarge),
            subtitle: contact != null && contact.company.isNotEmpty
                ? Text(contact.company)
                : null,
          ),
          const Divider(),
          for (final String n in numbers)
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: Text(ltr(n)),
              subtitle: Text(context.l10n.call),
              onTap: () {
                Navigator.of(sheet).pop();
                placeCall(ref, n);
              },
              // P12: only when the carrier offers video calls.
              trailing: Consumer(
                builder: (BuildContext _, WidgetRef inner, Widget? _) =>
                    inner.watch(callFeaturesProvider).value?.video ?? false
                    ? IconButton(
                        tooltip: context.l10n.videoCall,
                        icon: const Icon(Icons.videocam_outlined),
                        onPressed: () {
                          Navigator.of(sheet).pop();
                          placeCall(ref, n, video: true);
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.message_outlined),
            title: Text(context.l10n.sendAMessage),
            onTap: () {
              Navigator.of(sheet).pop();
              sendMessage(number);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(context.l10n.callHistory),
            onTap: () {
              Navigator.of(sheet).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CallDetailsPage(number: number),
                ),
              );
            },
          ),
          if (contact != null)
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(context.l10n.ringtoneVoicemailSim),
              onTap: () {
                Navigator.of(sheet).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ContactCallSettingsPage(contact: contact),
                  ),
                );
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.person_add_alt_outlined),
              title: Text(context.l10n.addToContacts),
              onTap: () {
                Navigator.of(sheet).pop();
                ref.read(telecomProvider).addContact(number);
              },
            ),
          ListTile(
            leading: const Icon(Icons.dialpad),
            title: Text(context.l10n.editBeforeCalling),
            onTap: () {
              Navigator.of(sheet).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DialpadPage(initialNumber: number),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: Text(context.l10n.copyNumber),
            onTap: () {
              Clipboard.setData(ClipboardData(text: number));
              Navigator.of(sheet).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: Text(context.l10n.blockNumber),
            subtitle: Text(context.l10n.blockNumberBody),
            onTap: () async {
              Navigator.of(sheet).pop();
              await confirmBlock(context, ref, number);
            },
          ),
        ],
      ),
    );
  },
);

Future<void> confirmBlock(
  BuildContext context,
  WidgetRef ref,
  String number,
) async {
  final Telecom telecom = ref.read(telecomProvider);
  if (!await telecom.canBlock()) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.setAsPhoneToBlock)));
    }
    return;
  }
  if (!context.mounted) return;
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext d) => AlertDialog(
      title: Text(d.l10n.blockNumberQuestion(ltr(number))),
      content: Text(d.l10n.blockNumberExplain),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(d).pop(false),
          child: Text(d.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(d).pop(true),
          child: Text(d.l10n.block),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await telecom.block(number);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.numberBlocked(ltr(number)))),
    );
  }
}
