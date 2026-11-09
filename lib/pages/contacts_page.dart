import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/pages/call_actions.dart';
import 'package:zerotrust_phone/pages/recents_page.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';

/// Contacts from ZT Contacts, read-only. Editing happens in ZT Contacts.
class ContactsPage extends ConsumerWidget {
  const ContactsPage({super.key, this.query = '', this.favoritesOnly = false});

  final String query;
  final bool favoritesOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PhoneContact>> contacts = ref.watch(
      phoneContactsProvider,
    );
    return contacts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => EmptyState(
        icon: Icons.contacts_outlined,
        text: 'Couldn\'t open your contacts. ${ztErrorMessage(e)}',
      ),
      data: (List<PhoneContact> all) {
        final List<PhoneContact> shown = all
            .where(
              (PhoneContact c) =>
                  c.phones.isNotEmpty &&
                  (!favoritesOnly || c.isFavorite) &&
                  c.matches(query),
            )
            .toList();
        if (shown.isEmpty) {
          if (query.isNotEmpty) {
            return EmptyState(
              icon: Icons.search_off,
              text: 'No contacts match "$query"',
            );
          }
          return favoritesOnly
              ? const EmptyState(
                  icon: Icons.star_outline,
                  text:
                      'No favorites yet.\nStar contacts in ZT Contacts and '
                      'they show up here.',
                )
              : const _NoContacts();
        }
        if (favoritesOnly && query.isEmpty) return _FavoritesGrid(shown);
        return ListView.builder(
          itemCount: shown.length,
          itemBuilder: (BuildContext context, int i) {
            final PhoneContact c = shown[i];
            final String letter = _letter(c.name);
            final bool header =
                query.isEmpty &&
                (i == 0 || _letter(shown[i - 1].name) != letter);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (header)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Semantics(
                      header: true,
                      child: Text(
                        letter,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ListTile(
                  leading: ContactAvatar(label: c.name),
                  title: Text(c.name),
                  subtitle: Text(
                    c.phones.first +
                        (c.phones.length > 1 ? ' +${c.phones.length - 1}' : ''),
                  ),
                  trailing: IconButton(
                    tooltip: 'Call ${c.name}',
                    icon: const Icon(Icons.call_outlined),
                    onPressed: () => placeCall(ref, c.phones.first),
                  ),
                  onTap: () => showNumberSheet(
                    context,
                    ref,
                    number: c.phones.first,
                    contact: c,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _letter(String name) {
    final String first = name.isEmpty ? '#' : name[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
  }
}

class _FavoritesGrid extends ConsumerWidget {
  const _FavoritesGrid(this.contacts);
  final List<PhoneContact> contacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GridView.builder(
    padding: const EdgeInsets.all(12),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 120,
      mainAxisExtent: 120,
    ),
    itemCount: contacts.length,
    itemBuilder: (BuildContext context, int i) {
      final PhoneContact c = contacts[i];
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => placeCall(ref, c.phones.first),
        onLongPress: () =>
            showNumberSheet(context, ref, number: c.phones.first, contact: c),
        child: Semantics(
          button: true,
          label: 'Call ${c.name}',
          excludeSemantics: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ContactAvatar(label: c.name, radius: 32),
              const SizedBox(height: 8),
              Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _NoContacts extends StatelessWidget {
  const _NoContacts();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.contacts_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text(
            'Your contacts come from ZT Contacts, end-to-end encrypted '
            'with the same account. Add some there and they show up here.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Get ZT Contacts'),
            onPressed: () => launchUrl(
              ZtSuite.contacts.marketUrl,
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    ),
  );
}
