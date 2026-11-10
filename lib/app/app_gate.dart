import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/app/auth_providers.dart';
import 'package:zerotrust_phone/app/history_retention.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/services/history_backup.dart';
import 'package:zerotrust_phone/services/screening_sync.dart';
import 'package:zerotrust_phone/pages/dialpad_page.dart';
import 'package:zerotrust_phone/pages/home_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

/// Routes between the shared account screens and the dialer.
///
/// Signed out: sign in or create an account. Signed in but locked (cold
/// start, auto-lock): unlock with the account password or biometrics. A new
/// recovery key is always shown, and confirmed, before the vault opens.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> with WidgetsBindingObserver {
  /// Stays on the sign-in screen until it hands back a result, even though
  /// Supabase reports the session a moment earlier.
  late bool _signingIn = ref.read(currentUserProvider) == null;
  UnlockResult? _awaitingRecoveryKey;

  late final Telecom _telecom = ref.read(telecomProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // DIAL and tel: links open the dialpad even while the vault is locked:
    // dialling never waits for an unlock (P6).
    _telecom.listenForDials();
    _telecom.dialRequests.addListener(_onDialRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onDialRequest());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _telecom.dialRequests.removeListener(_onDialRequest);
    super.dispose();
  }

  Future<void> _onDialRequest() async {
    final String? number = await _telecom.consumeDial();
    if (number == null || !mounted) return;
    _openDialpad(number);
  }

  void _openDialpad([String number = '']) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => DialpadPage(initialNumber: number)),
  );

  /// Sign-in and unlock screens get a dialpad button, so a call (including
  /// an emergency call) never needs the password.
  Widget _withDialpad(Widget screen) => Stack(
    children: <Widget>[
      screen,
      Positioned(
        top: 0,
        left: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton.filledTonal(
              tooltip: 'Dialpad, no unlock needed',
              icon: const Icon(Icons.dialpad),
              onPressed: _openDialpad,
            ),
          ),
        ),
      ),
    ],
  );

  /// A key still waiting behind the recovery-key screen is zeroed when the
  /// app leaves the foreground, so coming back asks for the password.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final UnlockResult? pending = _awaitingRecoveryKey;
      if (pending != null) {
        pending.dek.fillRange(0, pending.dek.length, 0);
        setState(() => _awaitingRecoveryKey = null);
      }
    }
  }

  Future<void> _onUnlocked(UnlockResult result) async {
    // Phone reads the address book ZT Contacts keeps in the same account,
    // so it also derives the Contacts key while it holds the account key.
    await ref.read(contactsKeyProvider.notifier).deriveFrom(result.dek);
    if (!mounted) return;
    if (result.newRecoveryKey != null) {
      setState(() {
        _signingIn = false;
        _awaitingRecoveryKey = result;
      });
      return;
    }
    setState(() => _signingIn = false);
    ref
        .read(vaultControllerProvider.notifier)
        .unlock(result.dek, legacyDek: result.legacyDek);
  }

  void _forgotPassword() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ZtForgotPasswordScreen()),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultControllerProvider, (_, VaultState next) {
      // Don't leave a page open over a locked vault.
      if (next is VaultLocked) {
        Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
      }
    });
    ref.listen(currentUserProvider, (_, user) {
      if (user == null) {
        // Screening hashes of the address book go with the account.
        _telecom.clearScreeningContacts().ignore();
        ref.read(vaultControllerProvider.notifier).lock();
        setState(() => _signingIn = true);
      }
    });

    final UnlockResult? pending = _awaitingRecoveryKey;
    if (pending != null) {
      return ZtRecoveryKeyScreen(
        recoveryKey: pending.newRecoveryKey!,
        onDone: () {
          setState(() => _awaitingRecoveryKey = null);
          ref
              .read(vaultControllerProvider.notifier)
              .unlock(pending.dek, legacyDek: pending.legacyDek);
        },
      );
    }

    if (ref.watch(passwordRecoveryProvider)) {
      return ZtResetPasswordScreen(
        onUnlocked: (UnlockResult result) {
          ref.read(passwordRecoveryProvider.notifier).done();
          _onUnlocked(result);
        },
      );
    }

    final user = ref.watch(currentUserProvider);
    if (user == null || _signingIn) {
      return _withDialpad(
        ZtSignInScreen(
          onUnlocked: _onUnlocked,
          onForgotPassword: _forgotPassword,
        ),
      );
    }

    if (ref.watch(vaultControllerProvider) is VaultLocked) {
      return _withDialpad(
        ZtUnlockScreen(
          email: user.email,
          onUnlocked: _onUnlocked,
          onSignOut: () => ref.read(accountServiceProvider).signOut(),
          onForgotPassword: _forgotPassword,
        ),
      );
    }

    // Touches count as activity for auto-lock: see ZeroTrustPhoneApp.
    return const _PhoneHome();
  }
}

/// The dialer once unlocked: keeps the Contacts names fresh, hands them to
/// the in-call screen (memory only) and to call screening (keyed hashes),
/// trims and backs up call history, and opens Recents from the missed-call
/// notification.
class _PhoneHome extends ConsumerStatefulWidget {
  const _PhoneHome();

  @override
  ConsumerState<_PhoneHome> createState() => _PhoneHomeState();
}

class _PhoneHomeState extends ConsumerState<_PhoneHome>
    with WidgetsBindingObserver {
  late final Telecom _telecom = ref.read(telecomProvider);
  ScreeningRules? _sentRules;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _telecom.recentsRequests.addListener(_onRecentsRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    await _onRecentsRequest();
    // Made default from Android's settings or Phone's own Settings row:
    // the permissions (notifications above all, which the incoming-call
    // card needs) were never asked for.
    if (await _telecom.isDefaultDialer()) {
      await _telecom.requestPermissions();
      ref.invalidate(callAlertsReadyProvider);
    }
    await ref.read(historyRetentionProvider.notifier).apply();
    await _backUp();
  }

  Future<void> _backUp() async {
    try {
      await ref.read(historyBackupProvider).backUp();
    } on Object {
      // Locked meanwhile, or offline: the next open tries again.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _telecom.recentsRequests.removeListener(_onRecentsRequest);
    _telecom.clearVaultNames().ignore();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // A call may have ended, or the default app changed, meanwhile.
      ref.invalidate(callLogProvider);
      ref.invalidate(defaultDialerProvider);
      ref.invalidate(callAlertsReadyProvider);
      _backUp();
    }
  }

  Future<void> _onRecentsRequest() async {
    if (await _telecom.consumeShowRecents() && mounted) {
      Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
      ref.read(homeTabProvider.notifier).show(HomeTab.recents);
    }
  }

  void _syncScreening() {
    final List<PhoneContact>? contacts = ref.read(phoneContactsProvider).value;
    final List<ContactCallSettings>? settings = ref
        .read(contactSettingsProvider)
        .value;
    // Wait for the address book and settings, so a half-loaded state never
    // marks every contact as unknown.
    if (contacts == null || settings == null) return;
    final ScreeningRules rules = ScreeningRules.build(
      contacts: contacts,
      settings: settings,
      protection: ref.read(callProtectionProvider),
    );
    if (rules.same(_sentRules)) return;
    _sentRules = rules;
    _telecom
        .setScreening(
          unknownMode: rules.unknownMode,
          blockHidden: rules.blockHidden,
          prefixes: rules.prefixes,
          contactKeys: rules.contactKeys,
          voicemailKeys: rules.voicemailKeys,
          ringtones: rules.ringtones,
        )
        .ignore();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(contactDirectoryProvider, (_, ContactDirectory next) {
      _telecom.setVaultNames(next.namesByKey).ignore();
    });
    ref.listen(phoneContactsProvider, (_, _) => _syncScreening());
    ref.listen(contactSettingsProvider, (_, _) => _syncScreening());
    ref.listen(callProtectionProvider, (_, _) => _syncScreening());
    // Phone's own synced store: settings, speed dial, call-history backup.
    ref.watch(ztSyncControllerProvider);
    return const HomePage();
  }
}
