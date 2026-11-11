import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/pages/call_actions.dart';
import 'package:zerotrust_phone/pages/recents_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

final blockedNumbersProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(telecomProvider).blockedNumbers(),
);

/// Android's blocked-numbers list, which the default Phone app manages.
class BlockedNumbersPage extends ConsumerWidget {
  const BlockedNumbersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<String>> blocked = ref.watch(blockedNumbersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.blockedNumbers)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(context.l10n.addANumber),
        onPressed: () => _add(context, ref),
      ),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => EmptyState(icon: Icons.block, text: '$e'),
        data: (List<String> numbers) => numbers.isEmpty
            ? EmptyState(icon: Icons.block, text: context.l10n.noBlockedNumbers)
            : ListView(
                children: <Widget>[
                  for (final String n in numbers)
                    ListTile(
                      leading: const Icon(Icons.block),
                      title: Text(ltr(n)),
                      trailing: TextButton(
                        child: Text(context.l10n.unblock),
                        onPressed: () async {
                          await ref.read(telecomProvider).unblock(n);
                          ref.invalidate(blockedNumbersProvider);
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final TextEditingController number = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text(d.l10n.blockANumber),
        content: TextField(
          controller: number,
          autofocus: true,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(labelText: d.l10n.phoneNumber),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: Text(d.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(number.text.trim()),
            child: Text(d.l10n.next),
          ),
        ],
      ),
    );
    number.dispose();
    if (value == null || value.isEmpty || !context.mounted) return;
    await confirmBlock(context, ref, value);
    ref.invalidate(blockedNumbersProvider);
  }
}
