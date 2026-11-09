import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/app/history_retention.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

class FakeTelecom extends Telecom {
  DateTime? deletedBefore;

  @override
  Future<int> deleteCallsBefore(DateTime before) async {
    deletedBefore = before;
    return 3;
  }
}

void main() {
  test('on a cold start the saved period is applied, not "Forever"', () async {
    final InMemoryPreferencesStore prefs = InMemoryPreferencesStore()
      ..values['call_history_keep_days'] = '7';
    final FakeTelecom telecom = FakeTelecom();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        ztPreferencesStoreProvider.overrideWithValue(prefs),
        telecomProvider.overrideWithValue(telecom),
      ],
    );
    addTearDown(container.dispose);

    final DateTime now = DateTime(2026, 11, 9);
    final int removed = await container
        .read(historyRetentionProvider.notifier)
        .apply(now: now);
    expect(removed, 3);
    expect(telecom.deletedBefore, DateTime(2026, 11, 2));
  });
}
