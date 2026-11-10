import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/pages/contacts_page.dart';
import 'package:zerotrust_phone/pages/dialpad_page.dart';
import 'package:zerotrust_phone/pages/recents_page.dart';
import 'package:zerotrust_phone/pages/settings_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

/// Favorites, Recents and Contacts, with search and the dialpad button.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _tab = 1;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openDialpad([String number = '']) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => DialpadPage(initialNumber: number)),
  );

  @override
  Widget build(BuildContext context) {
    final bool searching = _query.isNotEmpty;
    final Widget body = searching
        ? ContactsPage(query: _query)
        : IndexedStack(
            index: _tab,
            children: const <Widget>[
              ContactsPage(favoritesOnly: true),
              RecentsPage(),
              ContactsPage(),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: SearchBar(
          controller: _search,
          hintText: 'Search contacts',
          leading: const Icon(Icons.search),
          elevation: const WidgetStatePropertyAll<double>(0),
          onChanged: (String v) => setState(() => _query = v.trim()),
          trailing: <Widget>[
            if (searching)
              IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _search.clear();
                  _query = '';
                }),
              ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PhoneSettingsPage(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const DefaultDialerBanner(),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'dial',
        tooltip: 'Dialpad',
        onPressed: _openDialpad,
        child: const Icon(Icons.dialpad),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (int i) {
          setState(() {
            _tab = i;
            _search.clear();
            _query = '';
          });
          if (i == 1) ref.read(telecomProvider).markMissedSeen().ignore();
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: 'Favorites',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Recents'),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
        ],
      ),
    );
  }
}

/// Asks to become the default Phone app, which the in-call screen, call
/// history and blocking need.
class DefaultDialerBanner extends ConsumerWidget {
  const DefaultDialerBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Telecom telecom = ref.watch(telecomProvider);
    if (!telecom.isSupported) return const SizedBox.shrink();
    final bool isDefault = ref.watch(defaultDialerProvider).value ?? true;
    if (isDefault) return const SizedBox.shrink();
    return MaterialBanner(
      leading: const Icon(Icons.phone_in_talk_outlined),
      content: const Text(
        'Make ZT Phone your Phone app to answer calls here, see your call '
        'history and block numbers.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            final bool ok = await telecom.requestDefaultDialer();
            if (ok) await telecom.requestPermissions();
            ref.invalidate(defaultDialerProvider);
            ref.invalidate(callLogProvider);
          },
          child: const Text('Set as default'),
        ),
      ],
    );
  }
}
