import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/services/quick_replies.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'unedited quick replies follow a language change; edited ones stay',
    () async {
      final ProviderContainer c = ProviderContainer(
        overrides: [
          ztPreferencesStoreProvider.overrideWithValue(
            InMemoryPreferencesStore(),
          ),
        ],
      );
      addTearDown(c.dispose);
      final List<String> english = await c.read(quickRepliesProvider.future);
      expect(english.first, lookupAppL10n(const Locale('en')).replyCantTalk);

      await c.read(ztLanguageProvider.notifier).set(ZtLanguages.hebrew);
      final List<String> hebrew = await c.read(quickRepliesProvider.future);
      expect(hebrew.first, lookupAppL10n(const Locale('he')).replyCantTalk);

      await c.read(quickRepliesProvider.notifier).save(<String>[
        'Call you soon',
      ]);
      await c.read(ztLanguageProvider.notifier).set(ZtLanguages.english);
      expect(await c.read(quickRepliesProvider.future), <String>[
        'Call you soon',
      ]);
    },
  );
}
