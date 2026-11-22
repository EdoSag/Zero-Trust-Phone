import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/services/spam_list.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
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
          const Divider(),
          const SpamListSection(),
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

/// P24: what happens to calls from numbers on the signed spam list, which
/// list is in use, and a manual check for a newer one.
class SpamListSection extends ConsumerStatefulWidget {
  const SpamListSection({super.key});

  @override
  ConsumerState<SpamListSection> createState() => _SpamListSectionState();
}

class _SpamListSectionState extends ConsumerState<SpamListSection> {
  ({String? date, int count})? _info;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final ({String? date, int count}) info = await ref
        .read(telecomProvider)
        .spamListInfo();
    if (mounted) setState(() => _info = info);
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final SpamListCheck result = await ref
        .read(spamListUpdaterProvider)
        .checkIfDue(ref.read(spamModeProvider), force: true);
    if (!mounted) return;
    setState(() => _checking = false);
    await _loadInfo();
    if (!mounted) return;
    final AppL10n l = context.l10n;
    final String? message = switch (result) {
      SpamListCheck.updated => l.spamUpdated,
      SpamListCheck.upToDate || SpamListCheck.notDue => l.spamUpToDate,
      SpamListCheck.failed => l.spamCheckFailed,
      SpamListCheck.off => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  static String label(AppL10n l, SpamMode m) => switch (m) {
    SpamMode.off => l.spamOff,
    SpamMode.warn => l.spamWarn,
    SpamMode.silence => l.spamSilence,
    SpamMode.voicemail => l.spamVoicemail,
  };

  @override
  Widget build(BuildContext context) {
    final AppL10n l = context.l10n;
    final ThemeData theme = Theme.of(context);
    final SpamMode mode = ref.watch(spamModeProvider);
    final ({String? date, int count})? info = _info;
    final String? date = info?.date;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l.spamHeader,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        RadioGroup<SpamMode>(
          groupValue: mode,
          onChanged: (SpamMode? v) async {
            if (v == null) return;
            await ref.read(spamModeProvider.notifier).set(v);
            // Turned on for the first time: get the list now.
            if (v != SpamMode.off && (_info?.count ?? 0) == 0) await _check();
          },
          child: Column(
            children: <Widget>[
              for (final SpamMode m in SpamMode.values)
                RadioListTile<SpamMode>(
                  key: ValueKey<String>('spam-${m.name}'),
                  value: m,
                  title: Text(label(l, m)),
                ),
            ],
          ),
        ),
        if (mode != SpamMode.off)
          ListTile(
            key: const ValueKey<String>('spam-check'),
            leading: _checking
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            title: Text(l.spamCheckNow),
            subtitle: Text(
              date == null || info == null
                  ? l.spamListNone
                  : l.spamListInfo(date.replaceFirst('T', ' '), info.count),
            ),
            onTap: _checking ? null : _check,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(l.spamExplain, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}
