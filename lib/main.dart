import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/app/app_gate.dart';
import 'package:zerotrust_phone/app/phone_config.dart';
import 'package:zerotrust_phone/call/in_call_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
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
void callMain() {
  WidgetsFlutterBinding.ensureInitialized();
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
        localizationsDelegates: const [
          ZtL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: ZtL10n.supportedLocales,
        home: const AppGate(),
        // Any touch on any screen counts as activity for auto-lock.
        builder: (BuildContext context, Widget? child) => Listener(
          onPointerDown: (_) =>
              ref.read(vaultControllerProvider.notifier).touch(),
          child: child,
        ),
      ),
    );
  }
}
