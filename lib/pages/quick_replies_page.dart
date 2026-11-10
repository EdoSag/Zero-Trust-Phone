import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/services/quick_replies.dart';

/// Edit the texts offered when declining a call (P3).
class QuickRepliesPage extends ConsumerWidget {
  const QuickRepliesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> replies =
        ref.watch(quickRepliesProvider).value ?? QuickReplies.defaults;
    final QuickReplies notifier = ref.read(quickRepliesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick replies'),
        actions: <Widget>[
          TextButton(
            onPressed: () => notifier.save(QuickReplies.defaults),
            child: const Text('Reset'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () async {
          final String? text = await _edit(context, '');
          if (text != null) await notifier.save(<String>[...replies, text]);
        },
      ),
      body: ListView(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Offered when a call comes in. The text goes out through your '
              'messaging app, from your number.',
            ),
          ),
          for (int i = 0; i < replies.length; i++)
            ListTile(
              leading: const Icon(Icons.message_outlined),
              title: Text(replies[i]),
              onTap: () async {
                final String? text = await _edit(context, replies[i]);
                if (text == null) return;
                await notifier.save(<String>[...replies]..[i] = text);
              },
              trailing: IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    notifier.save(<String>[...replies]..removeAt(i)),
              ),
            ),
        ],
      ),
    );
  }

  Future<String?> _edit(BuildContext context, String initial) async {
    final TextEditingController c = TextEditingController(text: initial);
    final String? out = await showDialog<String>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text(initial.isEmpty ? 'New reply' : 'Edit reply'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 160,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(c.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    return (out == null || out.trim().isEmpty) ? null : out.trim();
  }
}
