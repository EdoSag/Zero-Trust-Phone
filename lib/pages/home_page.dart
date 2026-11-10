import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/pages/contacts_page.dart';
import 'package:zerotrust_phone/pages/dialpad_page.dart';
import 'package:zerotrust_phone/pages/favorites_page.dart';
import 'package:zerotrust_phone/pages/recents_page.dart';
import 'package:zerotrust_phone/pages/settings_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

enum HomeTab { favorites, recents, contacts }

/// The tab on show; the missed-call notification switches it to Recents.
final homeTabProvider = NotifierProvider<HomeTabController, HomeTab>(
  HomeTabController.new,
);

class HomeTabController extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.recents;

  void show(HomeTab tab) => state = tab;
}

/// Favorites, Recents and Contacts, with search and the dialpad button.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
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
    final HomeTab tab = ref.watch(homeTabProvider);
    final bool searching = _query.isNotEmpty;
    // On Recents the search filters the call history (P4); elsewhere it
    // finds contacts.
    final Widget body = searching
        ? (tab == HomeTab.recents
              ? RecentsPage(query: _query)
              : ContactsPage(query: _query))
        : IndexedStack(
            index: tab.index,
            children: const <Widget>[
              FavoritesPage(),
              RecentsPage(),
              ContactsPage(),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: SearchBar(
          controller: _search,
          hintText: tab == HomeTab.recents ? 'Search calls' : 'Search contacts',
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
        selectedIndex: tab.index,
        onDestinationSelected: (int i) {
          ref.read(homeTabProvider.notifier).show(HomeTab.values[i]);
          setState(() {
            _search.clear();
            _query = '';
          });
          if (HomeTab.values[i] == HomeTab.recents) {
            ref.read(telecomProvider).markMissedSeen().ignore();
          }
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
    if (isDefault) {
      final bool alertsOk = ref.watch(callAlertsReadyProvider).value ?? true;
      if (alertsOk) return const SizedBox.shrink();
      return MaterialBanner(
        leading: const Icon(Icons.notifications_off_outlined),
        content: const Text(
          'Incoming calls can\'t show on the lock screen or as a '
          'notification. Allow call notifications for ZT Phone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              // Asks for the notification permission first; if it was
              // refused before, opens the system setting instead.
              await telecom.requestPermissions();
              if (!await telecom.callAlertsReady()) {
                await telecom.fixCallAlerts();
              }
              ref.invalidate(callAlertsReadyProvider);
            },
            child: const Text('Allow'),
          ),
        ],
      );
    }
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
