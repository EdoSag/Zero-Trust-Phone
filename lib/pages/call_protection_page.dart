import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// Spam and unknown-caller protection (P1). Everything is decided on the
/// phone: no number is sent anywhere to be checked.
class CallProtectionPage extends ConsumerWidget {
  const CallProtectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CallProtection p = ref.watch(callProtectionProvider);
    final PhoneData data = ref.read(phoneDataProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.callProtection)),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              context.l10n.unknownCallersHeader,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          RadioGroup<UnknownCallers>(
            groupValue: p.unknownCallers,
            onChanged: (UnknownCallers? v) {
              if (v != null) data.saveProtection(p.copyWith(unknownCallers: v));
            },
            child: Column(
              children: <Widget>[
                for (final UnknownCallers u in UnknownCallers.values)
                  RadioListTile<UnknownCallers>(
                    value: u,
                    title: Text(unknownCallersLabel(context.l10n, u)),
                  ),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: Text(context.l10n.blockHidden),
            subtitle: Text(context.l10n.blockHiddenBody),
            value: p.blockHidden,
            onChanged: (bool v) =>
                data.saveProtection(p.copyWith(blockHidden: v)),
          ),
          const Divider(),
          ListTile(
            title: Text(context.l10n.blockedPrefixes),
            subtitle: Text(context.l10n.blockedPrefixesBody),
            trailing: IconButton(
              tooltip: context.l10n.addPrefix,
              icon: const Icon(Icons.add),
              onPressed: () => _addPrefix(context, data, p),
            ),
          ),
          for (final String prefix in p.blockedPrefixes)
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(ltr(prefix)),
              trailing: IconButton(
                tooltip: context.l10n.removePrefix(ltr(prefix)),
                icon: const Icon(Icons.close),
                onPressed: () => data.saveProtection(
                  p.copyWith(
                    blockedPrefixes: <String>[
                      for (final String x in p.blockedPrefixes)
                        if (x != prefix) x,
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.protectionExplain),
          ),
        ],
      ),
    );
  }

  /// What each choice for unknown callers is called.
  static String unknownCallersLabel(AppL10n l, UnknownCallers u) => switch (u) {
    UnknownCallers.ring => l.unknownRing,
    UnknownCallers.silence => l.unknownSilence,
    UnknownCallers.voicemail => l.unknownVoicemail,
  };

  Future<void> _addPrefix(
    BuildContext context,
    PhoneData data,
    CallProtection p,
  ) async {
    final TextEditingController c = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text(d.l10n.blockStartingWith),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(hintText: '+1900'),
          onSubmitted: (String v) => Navigator.of(d).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: Text(d.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(c.text),
            child: Text(d.l10n.block),
          ),
        ],
      ),
    );
    c.dispose();
    final String clean = (value ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.replaceAll('+', '').length < 2) return;
    if (p.blockedPrefixes.contains(clean)) return;
    await data.saveProtection(
      p.copyWith(blockedPrefixes: <String>[...p.blockedPrefixes, clean]),
    );
  }
}
