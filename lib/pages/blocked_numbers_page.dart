import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/pages/call_actions.dart';
import 'package:zerotrust_phone/pages/recents_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

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
      appBar: AppBar(title: const Text('Blocked numbers')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add a number'),
        onPressed: () => _add(context, ref),
      ),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => EmptyState(icon: Icons.block, text: '$e'),
        data: (List<String> numbers) => numbers.isEmpty
            ? const EmptyState(
                icon: Icons.block,
                text:
                    'No blocked numbers.\nBlock a number from Recents or '
                    'from here.',
              )
            : ListView(
                children: <Widget>[
                  for (final String n in numbers)
                    ListTile(
                      leading: const Icon(Icons.block),
                      title: Text(n),
                      trailing: TextButton(
                        child: const Text('Unblock'),
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
        title: const Text('Block a number'),
        content: TextField(
          controller: number,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone number'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(number.text.trim()),
            child: const Text('Next'),
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
