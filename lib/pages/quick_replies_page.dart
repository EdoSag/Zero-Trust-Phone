import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/services/quick_replies.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

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
        title: Text(context.l10n.quickReplies),
        actions: <Widget>[
          TextButton(
            onPressed: () => notifier.save(QuickReplies.defaults),
            child: Text(context.l10n.reset),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(context.l10n.add),
        onPressed: () async {
          final String? text = await _edit(context, '');
          if (text != null) await notifier.save(<String>[...replies, text]);
        },
      ),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.quickRepliesExplain),
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
                tooltip: context.l10n.delete,
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
        title: Text(initial.isEmpty ? d.l10n.newReply : d.l10n.editReply),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 160,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: Text(d.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(c.text),
            child: Text(d.l10n.save),
          ),
        ],
      ),
    );
    c.dispose();
    return (out == null || out.trim().isEmpty) ? null : out.trim();
  }
}
