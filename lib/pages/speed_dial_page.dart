import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';

/// Picks a contact (and number) for speed dial [digit], and saves it.
Future<void> assignSpeedDial(
  BuildContext context,
  WidgetRef ref,
  int digit,
) async {
  final List<PhoneContact> contacts =
      (ref.read(phoneContactsProvider).value ?? const <PhoneContact>[])
          .where((PhoneContact c) => c.phones.isNotEmpty)
          .toList();
  final (PhoneContact, String)? picked = await Navigator.of(context)
      .push<(PhoneContact, String)>(
        MaterialPageRoute<(PhoneContact, String)>(
          builder: (_) => _ContactPicker(contacts: contacts, digit: digit),
        ),
      );
  if (picked == null) return;
  try {
    await ref
        .read(phoneDataProvider)
        .saveSpeedDial(
          SpeedDial(
            digit: digit,
            number: picked.$2,
            name: picked.$1.name,
            contactId: picked.$1.id,
          ),
        );
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock ZT Phone to change speed dial')),
      );
    }
  }
}

/// Speed dial 2 to 9 (P8). 1 is voicemail.
class SpeedDialPage extends ConsumerWidget {
  const SpeedDialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SpeedDial> dials =
        ref.watch(speedDialsProvider).value ?? const <SpeedDial>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Speed dial')),
      body: ListView(
        children: <Widget>[
          const ListTile(
            leading: CircleAvatar(child: Text('1')),
            title: Text('Voicemail'),
            subtitle: Text('Hold 1 on the dialpad'),
          ),
          for (int d = 2; d <= 9; d++)
            Builder(
              builder: (BuildContext context) {
                final SpeedDial? dial = dials
                    .where((SpeedDial s) => s.digit == d)
                    .firstOrNull;
                return ListTile(
                  leading: CircleAvatar(child: Text('$d')),
                  title: Text(dial?.name ?? 'Not set'),
                  subtitle: dial == null ? null : Text(dial.number),
                  trailing: dial == null
                      ? null
                      : IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              ref.read(phoneDataProvider).clearSpeedDial(d),
                        ),
                  onTap: () => assignSpeedDial(context, ref, d),
                );
              },
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Hold a number on the dialpad to call. Saved '
              'encrypted in your account.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactPicker extends StatefulWidget {
  const _ContactPicker({required this.contacts, required this.digit});
  final List<PhoneContact> contacts;
  final int digit;

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final List<PhoneContact> shown = widget.contacts
        .where((PhoneContact c) => c.matches(_query))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Speed dial ${widget.digit}: search contacts',
            border: InputBorder.none,
          ),
          onChanged: (String v) => setState(() => _query = v),
        ),
      ),
      body: shown.isEmpty
          ? const Center(child: Text('No contacts with a phone number'))
          : ListView(
              children: <Widget>[
                for (final PhoneContact c in shown)
                  for (final String p in c.phones)
                    ListTile(
                      leading: ContactAvatar(label: c.name),
                      title: Text(c.name),
                      subtitle: Text(p),
                      onTap: () => Navigator.of(context).pop((c, p)),
                    ),
              ],
            ),
    );
  }
}
