import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/services/notes_bridge.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// The text "Text my card" sends from the call screen (P27): a contact's
/// name, numbers and company.
String cardText(PhoneContact c) => <String>[
  c.name,
  if (c.company.isNotEmpty && c.company != c.name) c.company,
  ...c.phones,
].join('\n');

/// Settings > My card (P27): pick my own card from ZT Contacts, or write
/// it. Kept in the phone's secure storage, because the call screen sends
/// it while ZT Phone is locked.
class MyCardPage extends ConsumerStatefulWidget {
  const MyCardPage({super.key});

  @override
  ConsumerState<MyCardPage> createState() => _MyCardPageState();
}

class _MyCardPageState extends ConsumerState<MyCardPage> {
  final TextEditingController _text = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final List<PhoneContact> contacts =
        ref.read(phoneContactsProvider).value ?? const <PhoneContact>[];
    final PhoneContact? picked = await showModalBottomSheet<PhoneContact>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheet) => DraggableScrollableSheet(
        expand: false,
        builder: (BuildContext _, ScrollController scroll) => ListView(
          controller: scroll,
          children: <Widget>[
            for (final PhoneContact c in contacts)
              ListTile(
                leading: ContactAvatar(label: c.name),
                title: Text(c.name),
                subtitle: c.phones.isEmpty ? null : Text(ltr(c.phones.first)),
                onTap: () => Navigator.of(sheet).pop(c),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _text.text = cardText(picked));
    await ref.read(myCardProvider.notifier).set(_text.text);
  }

  @override
  Widget build(BuildContext context) {
    final AppL10n l = context.l10n;
    final AsyncValue<String?> card = ref.watch(myCardProvider);
    if (!_loaded && card.hasValue) {
      _loaded = true;
      _text.text = card.value ?? '';
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.myCard)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(l.myCardBody),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey<String>('pick-card'),
            icon: const Icon(Icons.contacts_outlined),
            label: Text(l.myCardPick),
            onPressed: _pick,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey<String>('card-text'),
            controller: _text,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: l.myCardText,
            ),
            onChanged: (String v) => ref
                .read(myCardProvider.notifier)
                .set(v.trim().isEmpty ? null : v.trim()),
          ),
        ],
      ),
    );
  }
}
