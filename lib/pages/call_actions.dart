import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/pages/call_details_page.dart';
import 'package:zerotrust_phone/pages/contact_call_settings_page.dart';
import 'package:zerotrust_phone/pages/dialpad_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';

/// Calls [number], on the contact's own SIM when one is set (P6).
Future<void> placeCall(WidgetRef ref, String number) {
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
  return ref.read(telecomProvider).placeCall(number, account: account);
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
              title: Text(n),
              subtitle: const Text('Call'),
              onTap: () {
                Navigator.of(sheet).pop();
                placeCall(ref, n);
              },
            ),
          ListTile(
            leading: const Icon(Icons.message_outlined),
            title: const Text('Send a message'),
            onTap: () {
              Navigator.of(sheet).pop();
              sendMessage(number);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Call history'),
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
              title: const Text('Ringtone, voicemail and SIM'),
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
              title: const Text('Add to contacts'),
              onTap: () {
                Navigator.of(sheet).pop();
                ref.read(telecomProvider).addContact(number);
              },
            ),
          ListTile(
            leading: const Icon(Icons.dialpad),
            title: const Text('Edit number before calling'),
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
            title: const Text('Copy number'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: number));
              Navigator.of(sheet).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Block number'),
            subtitle: const Text('Calls from it are silently declined'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set ZT Phone as your Phone app to block numbers'),
        ),
      );
    }
    return;
  }
  if (!context.mounted) return;
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext d) => AlertDialog(
      title: Text('Block $number?'),
      content: const Text(
        'You won\'t get calls or texts from this number. Android keeps the '
        'list, so it also applies in other phone and messaging apps.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(d).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(d).pop(true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await telecom.block(number);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$number blocked')));
  }
}
