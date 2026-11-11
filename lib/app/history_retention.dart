import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// How long the phone keeps call history. Older calls are deleted from
/// Android's call log each time ZT Phone opens. Null keeps everything.
final historyRetentionProvider = NotifierProvider<HistoryRetention, int?>(
  HistoryRetention.new,
);

class HistoryRetention extends Notifier<int?> {
  static const String _key = 'call_history_keep_days';
  static const List<int?> choices = <int?>[null, 90, 30, 7, 1];

  late Future<void> _loaded;

  @override
  int? build() {
    _loaded = _load();
    return null;
  }

  Future<void> _load() async {
    final String? raw = await ref.read(ztPreferencesStoreProvider).read(_key);
    final int? days = int.tryParse(raw ?? '');
    if (days != null && days > 0) state = days;
  }

  Future<void> set(int? days) async {
    await _loaded;
    state = days;
    await ref.read(ztPreferencesStoreProvider).write(_key, '${days ?? 0}');
    await apply();
  }

  /// Deletes calls older than the chosen period. Returns how many.
  Future<int> apply({DateTime? now}) async {
    await _loaded; // The saved period, not the default, on a cold start.
    final int? days = state;
    if (days == null) return 0;
    final DateTime cutoff = (now ?? DateTime.now()).subtract(
      Duration(days: days),
    );
    final int removed = await ref
        .read(telecomProvider)
        .deleteCallsBefore(cutoff);
    if (removed > 0) ref.invalidate(callLogProvider);
    return removed;
  }

  static String label(int? days) => switch (days) {
    null => currentL10n.retentionForever,
    1 => currentL10n.retention24h,
    _ => currentL10n.retentionDays(days),
  };
}
