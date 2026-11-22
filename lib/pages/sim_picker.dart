import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// What the SIM picker decided for one call (P18).
sealed class SimPick {
  const SimPick();
}

/// Call on this SIM; null = let Android choose (one SIM, or its default).
class SimChosen extends SimPick {
  const SimChosen(this.accountId);
  final String? accountId;
}

/// The picker was closed: don't call.
class SimCancelled extends SimPick {
  const SimCancelled();
}

/// The SIM to call [number] on, when the contact has none set (P18).
///
/// One SIM, or a default SIM chosen in Android's settings: Android's
/// choice, without asking. A SIM remembered for this number: that one.
/// Otherwise, or always when [ask] (long-press on the call button), the
/// picker, whose "Remember for this number" saves the choice in the vault.
Future<SimPick> pickSimFor(
  WidgetRef ref,
  String number, {
  bool ask = false,
}) async {
  final Telecom telecom = ref.read(telecomProvider);
  final List<PhoneAccount> sims;
  final String? systemDefault;
  try {
    sims = await telecom.phoneAccounts();
    systemDefault = await telecom.defaultPhoneAccount();
  } on Object {
    return const SimChosen(null);
  }
  if (sims.length < 2) return const SimChosen(null);
  final String key = PhoneNumbers.lookupKey(number);
  // Awaited, and listened to while it loads (an unwatched provider is
  // paused): on the first call after start the list is still loading.
  final ProviderSubscription<Future<List<SimChoice>>> memory = ref.listenManual(
    simChoicesProvider.future,
    (_, _) {},
  );
  List<SimChoice> remembered;
  try {
    remembered = await memory.read().timeout(const Duration(seconds: 2));
  } on Object {
    remembered = const <SimChoice>[];
  } finally {
    memory.close();
  }
  final SimChoice? saved = remembered
      .where((SimChoice c) => c.key == key)
      .firstOrNull;
  final bool savedStillHere =
      saved != null && sims.any((PhoneAccount a) => a.id == saved.accountId);
  if (!ask) {
    if (savedStillHere) return SimChosen(saved.accountId);
    if (systemDefault != null) return const SimChosen(null);
  }
  final BuildContext context = ref.context;
  if (!context.mounted) return const SimChosen(null);
  final (PhoneAccount, bool)? picked = await showSimPicker(
    context,
    sims: sims,
    current: savedStillHere ? saved.accountId : null,
    remember: savedStillHere,
  );
  if (picked == null) return const SimCancelled();
  final (PhoneAccount sim, bool remember) = picked;
  final PhoneData data = ref.read(phoneDataProvider);
  if (key.isNotEmpty) {
    try {
      if (remember) {
        await data.saveSimChoice(
          SimChoice(
            key: key,
            number: number,
            accountId: sim.id,
            accountLabel: sim.label,
          ),
        );
      } else if (saved != null) {
        await data.deleteSimChoice(key);
      }
    } on Object {
      // Locked mid-way: the call still goes out on the picked SIM.
    }
  }
  return SimChosen(sim.id);
}

/// The SIM picker sheet: one row per SIM and "Remember for this number".
Future<(PhoneAccount, bool)?> showSimPicker(
  BuildContext context, {
  required List<PhoneAccount> sims,
  String? current,
  bool remember = false,
}) => showModalBottomSheet<(PhoneAccount, bool)>(
  context: context,
  showDragHandle: true,
  builder: (BuildContext sheet) {
    bool keep = remember;
    return StatefulBuilder(
      builder: (BuildContext _, StateSetter setSheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                sheet.l10n.callWith,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            for (final (int i, PhoneAccount sim) in sims.indexed)
              ListTile(
                key: ValueKey<String>('sim-${sim.id}'),
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(sim.label),
                trailing: sim.id == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(sheet).pop((sim, keep)),
              ),
            SwitchListTile(
              key: const ValueKey<String>('sim-remember'),
              title: Text(sheet.l10n.rememberSimForNumber),
              subtitle: Text(sheet.l10n.rememberSimForNumberBody),
              value: keep,
              onChanged: (bool on) => setSheet(() => keep = on),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  },
);

/// Settings > SIM for each number: the remembered choices, to forget.
class SimChoicesPage extends ConsumerWidget {
  const SimChoicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SimChoice> choices =
        ref.watch(simChoicesProvider).value ?? const <SimChoice>[];
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.simPerNumber)),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(context.l10n.simPerNumberBody),
          ),
          if (choices.isEmpty)
            ListTile(title: Text(context.l10n.simPerNumberEmpty)),
          for (final SimChoice c in choices)
            ListTile(
              leading: const Icon(Icons.sim_card_outlined),
              title: Text(ltr(c.number)),
              subtitle: Text(c.accountLabel),
              trailing: IconButton(
                tooltip: context.l10n.forget,
                icon: const Icon(Icons.close),
                onPressed: () =>
                    ref.read(phoneDataProvider).deleteSimChoice(c.key),
              ),
            ),
        ],
      ),
    );
  }
}
