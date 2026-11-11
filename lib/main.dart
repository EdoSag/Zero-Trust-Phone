import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/app/app_gate.dart';
import 'package:zerotrust_phone/app/native_strings.dart';
import 'package:zerotrust_phone/app/phone_config.dart';
import 'package:zerotrust_phone/call/in_call_app.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  // English or Hebrew, as picked in Settings, from the first frame.
  await ZtLanguageController.preload();
  runApp(
    ProviderScope(
      overrides: [ztAppConfigProvider.overrideWithValue(phoneAppConfig)],
      child: const ZeroTrustPhoneApp(),
    ),
  );
}

/// The in-call screen's own entry point (see CallActivity.kt). No account,
/// no vault and no network: a call must show at once, even when locked.
@pragma('vm:entry-point')
Future<void> callMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The language picked in settings, but never hold up a ringing call for
  // it: after a moment the screen shows and switches when it's read.
  await ZtLanguageController.preload().timeout(
    const Duration(milliseconds: 150),
    onTimeout: () {},
  );
  runApp(
    ProviderScope(
      overrides: [ztAppConfigProvider.overrideWithValue(phoneAppConfig)],
      child: const InCallApp(),
    ),
  );
}

class ZeroTrustPhoneApp extends ConsumerWidget {
  const ZeroTrustPhoneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ZtThemeBuilder(
      builder: (context, theme, darkTheme, mode) => MaterialApp(
        // On-device task switcher label; the store name is Zero-Trust Phone.
        title: 'ZT Phone',
        theme: theme,
        darkTheme: darkTheme,
        themeMode: mode,
        // English (default) or Hebrew, from Settings → Appearance → Language.
        locale: ref.watch(ztLanguageProvider),
        supportedLocales: ZtLanguages.supported,
        localizationsDelegates: const [
          AppL10n.delegate,
          ...ZtLanguages.delegates,
        ],
        home: const AppGate(),
        // Any touch on any screen counts as activity for auto-lock.
        builder: (BuildContext context, Widget? child) => Listener(
          onPointerDown: (_) =>
              ref.read(vaultControllerProvider.notifier).touch(),
          // Notifications shown by Android follow the app's language too.
          child: NativeStringsSync(child: child!),
        ),
      ),
    );
  }
}
