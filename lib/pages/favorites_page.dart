import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/pages/call_actions.dart';
import 'package:zerotrust_phone/pages/recents_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';

/// Starred contacts, then the people you call most (P8).
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  /// The numbers called or answered most, most first, skipping favorites.
  static List<(String number, PhoneContact? contact)> frequent(
    List<CallLogEntry> log,
    ContactDirectory directory, {
    int limit = 8,
  }) {
    final Map<String, int> counts = <String, int>{};
    final Map<String, String> numbers = <String, String>{};
    for (final CallLogEntry e in log) {
      if (e.type != CallType.outgoing && e.type != CallType.incoming) continue;
      final String key = PhoneNumbers.lookupKey(e.number);
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      numbers.putIfAbsent(key, () => e.number);
    }
    final List<String> keys =
        counts.keys.where((String k) => counts[k]! >= 2).toList()
          ..sort((String a, String b) => counts[b]!.compareTo(counts[a]!));
    final List<(String, PhoneContact?)> out = <(String, PhoneContact?)>[];
    final Set<String> seenContacts = <String>{};
    for (final String k in keys) {
      final PhoneContact? c = directory.lookup(numbers[k]!);
      if (c != null && (c.isFavorite || !seenContacts.add(c.id))) continue;
      out.add((numbers[k]!, c));
      if (out.length >= limit) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<PhoneContact> favorites =
        (ref.watch(phoneContactsProvider).value ?? const <PhoneContact>[])
            .where((PhoneContact c) => c.isFavorite && c.phones.isNotEmpty)
            .toList();
    final List<(String, PhoneContact?)> often = frequent(
      ref.watch(callLogProvider).value ?? const <CallLogEntry>[],
      ref.watch(contactDirectoryProvider),
    );
    if (favorites.isEmpty && often.isEmpty) {
      return const EmptyState(
        icon: Icons.star_outline,
        text:
            'No favorites yet.\nStar contacts in ZT Contacts and they show '
            'up here, with the people you call most.',
      );
    }
    final ThemeData theme = Theme.of(context);
    return CustomScrollView(
      slivers: <Widget>[
        if (favorites.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                mainAxisExtent: 120,
              ),
              itemCount: favorites.length,
              itemBuilder: (BuildContext context, int i) {
                final PhoneContact c = favorites[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => placeCall(ref, c.phones.first),
                  onLongPress: () => showNumberSheet(
                    context,
                    ref,
                    number: c.phones.first,
                    contact: c,
                  ),
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
            ),
          ),
        if (often.isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Semantics(
                header: true,
                child: Text(
                  'Frequent',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: often.length,
            itemBuilder: (BuildContext context, int i) {
              final (String number, PhoneContact? c) = often[i];
              final String title = c?.name ?? number;
              return ListTile(
                leading: ContactAvatar(label: c?.name ?? ''),
                title: Text(title),
                subtitle: c == null ? null : Text(number),
                trailing: IconButton(
                  tooltip: 'Call $title',
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => placeCall(ref, number),
                ),
                onTap: () =>
                    showNumberSheet(context, ref, number: number, contact: c),
              );
            },
          ),
        ],
      ],
    );
  }
}
