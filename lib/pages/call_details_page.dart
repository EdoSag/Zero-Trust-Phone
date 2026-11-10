import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/pages/call_actions.dart';
import 'package:zerotrust_phone/pages/contact_call_settings_page.dart';
import 'package:zerotrust_phone/pages/recents_page.dart';
import 'package:zerotrust_phone/services/history_backup.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';

/// Every call with one number, with its length, and what to do next (P4).
class CallDetailsPage extends ConsumerWidget {
  const CallDetailsPage({super.key, required this.number});

  final String number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PhoneContact? contact = ref
        .watch(contactDirectoryProvider)
        .lookup(number);
    final List<CallLogEntry> calls =
        (ref.watch(callLogProvider).value ?? const <CallLogEntry>[])
            .where((CallLogEntry e) => PhoneNumbers.same(e.number, number))
            .toList();
    final String title =
        contact?.name ??
        calls.map((CallLogEntry e) => e.cachedName).nonNulls.firstOrNull ??
        number;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          if (calls.isNotEmpty)
            IconButton(
              tooltip: 'Delete this history',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteAll(context, ref, calls),
            ),
        ],
      ),
      body: ListView(
        children: <Widget>[
          const SizedBox(height: 8),
          Center(child: ContactAvatar(label: contact?.name ?? '', radius: 40)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          if (title != number) Center(child: Text(number)),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                icon: const Icon(Icons.call),
                label: const Text('Call'),
                onPressed: () => placeCall(ref, number),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.message_outlined),
                label: const Text('Message'),
                onPressed: () => sendMessage(number),
              ),
              if (contact == null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt_outlined),
                  label: const Text('Add to contacts'),
                  onPressed: () => ref.read(telecomProvider).addContact(number),
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.tune),
                  label: const Text('Call settings'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ContactCallSettingsPage(contact: contact),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.block),
                label: const Text('Block'),
                onPressed: () => confirmBlock(context, ref, number),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          if (calls.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No calls in this phone\'s history.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final CallLogEntry c in calls)
            ListTile(
              leading: Icon(
                callTypeIcon(c.type).$1,
                color: c.type == CallType.missed
                    ? theme.colorScheme.error
                    : null,
              ),
              title: Text(callTypeIcon(c.type).$2),
              subtitle: Text(
                '${dayLabel(c.date, DateTime.now())}, '
                '${TimeOfDay.fromDateTime(c.date).format(context)}',
              ),
              trailing: c.duration > Duration.zero
                  ? Text(formatDuration(c.duration))
                  : null,
            ),
        ],
      ),
    );
  }

  Future<void> _deleteAll(
    BuildContext context,
    WidgetRef ref,
    List<CallLogEntry> calls,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text(
          'Delete ${calls.length} '
          '${calls.length == 1 ? 'call' : 'calls'} from history?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(telecomProvider).deleteCalls(<int>[
      for (final CallLogEntry c in calls) c.id,
    ]);
    await ref.read(historyBackupProvider).forget(calls).catchError((_) {});
    ref.invalidate(callLogProvider);
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// "1:05", "12 sec", "1:02:03".
String formatDuration(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds} sec';
  String two(int n) => n.toString().padLeft(2, '0');
  final String ms = '${d.inMinutes % 60}:${two(d.inSeconds % 60)}';
  return d.inHours > 0
      ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
      : ms;
}

(IconData, String) callTypeIcon(CallType t) => switch (t) {
  CallType.incoming => (Icons.call_received, 'Incoming'),
  CallType.outgoing => (Icons.call_made, 'Outgoing'),
  CallType.missed => (Icons.call_missed, 'Missed'),
  CallType.rejected => (Icons.call_end, 'Declined'),
  CallType.blocked => (Icons.block, 'Blocked'),
  CallType.voicemail => (Icons.voicemail, 'Voicemail'),
  CallType.other => (Icons.call, 'Call'),
};
