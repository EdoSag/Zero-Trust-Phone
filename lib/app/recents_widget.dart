import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// "Show details on the home screen" for the Recent calls widget (W11).
/// Off by default, like every Zero-Trust widget: the widget then shows only
/// a lock and the number of new missed calls. On this phone only.
final recentsWidgetDetailsProvider =
    NotifierProvider<RecentsWidgetDetails, bool>(RecentsWidgetDetails.new);

class RecentsWidgetDetails extends Notifier<bool> {
  static const String key = 'recents_widget_details';
  late Future<void> loaded;

  @override
  bool build() {
    loaded = _load();
    return false;
  }

  Future<void> _load() async {
    try {
      state = await ref.read(ztPreferencesStoreProvider).read(key) == 'on';
    } on Object {
      // Unreadable: stays off.
    }
  }

  Future<void> set(bool on) async {
    await loaded;
    state = on;
    await ref.read(ztPreferencesStoreProvider).write(key, on ? 'on' : 'off');
  }
}

/// The contact names the widget may keep unencrypted: every ZT Contacts
/// name by lookup key, except private contacts (P23).
Map<String, String> widgetNames(
  Map<String, String> namesByKey,
  Iterable<String> privateKeys,
) {
  final Set<String> hidden = privateKeys.toSet();
  return <String, String>{
    for (final MapEntry<String, String> e in namesByKey.entries)
      if (!hidden.contains(e.key) && e.value.trim().isNotEmpty) e.key: e.value,
  };
}
