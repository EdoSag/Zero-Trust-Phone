import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/data/phone_items.dart';

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
      appBar: AppBar(title: const Text('Call protection')),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Calls from numbers not in your contacts',
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
                  RadioListTile<UnknownCallers>(value: u, title: Text(u.label)),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: const Text('Block hidden numbers'),
            subtitle: const Text('Private and unknown caller IDs'),
            value: p.blockHidden,
            onChanged: (bool v) =>
                data.saveProtection(p.copyWith(blockHidden: v)),
          ),
          const Divider(),
          ListTile(
            title: const Text('Blocked prefixes and countries'),
            subtitle: const Text(
              'Block every number that starts with, for example, +1900 or '
              'a whole country such as +44',
            ),
            trailing: IconButton(
              tooltip: 'Add prefix',
              icon: const Icon(Icons.add),
              onPressed: () => _addPrefix(context, data, p),
            ),
          ),
          for (final String prefix in p.blockedPrefixes)
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(prefix),
              trailing: IconButton(
                tooltip: 'Remove $prefix',
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
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Contacts you block or send to voicemail in ZT Contacts are '
              'handled here too. Rules work while ZT Phone is locked, and '
              'your contacts always ring unless you send them to voicemail.',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPrefix(
    BuildContext context,
    PhoneData data,
    CallProtection p,
  ) async {
    final TextEditingController c = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: const Text('Block numbers starting with'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '+1900'),
          onSubmitted: (String v) => Navigator.of(d).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(c.text),
            child: const Text('Block'),
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
