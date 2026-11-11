import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// "Start calls with real-time text" (P12). Kept on this phone only: it's
/// about this phone's carrier and the person holding it.
final startWithRttProvider = NotifierProvider<StartWithRtt, bool>(
  StartWithRtt.new,
);

class StartWithRtt extends Notifier<bool> {
  static const String _key = 'rtt_start_calls';

  /// Done once the saved choice is read; await before placing a call.
  late Future<void> loaded;

  @override
  bool build() {
    loaded = _load();
    return false;
  }

  Future<void> _load() async {
    final String? raw = await ref.read(ztPreferencesStoreProvider).read(_key);
    if (raw == '1') state = true;
  }

  Future<void> set(bool on) async {
    await loaded;
    state = on;
    await ref.read(ztPreferencesStoreProvider).write(_key, on ? '1' : '0');
  }
}
