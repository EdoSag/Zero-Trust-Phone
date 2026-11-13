import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/pages/call_actions.dart';
import 'package:zerotrust_phone/pages/call_back_sheet.dart';
import 'package:zerotrust_phone/pages/call_stats_page.dart';
import 'package:zerotrust_phone/pages/contact_call_settings_page.dart';
import 'package:zerotrust_phone/pages/dial_shortcut_page.dart';
import 'package:zerotrust_phone/pages/recents_page.dart';
import 'package:zerotrust_phone/services/private_calls.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';
import 'package:zerotrust_phone/widgets/country_time_hint.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

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
        (ref.watch(allCallsProvider).value ?? const <CallLogEntry>[])
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
              tooltip: context.l10n.deleteThisHistory,
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
              title == number ? ltr(number) : title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          if (title != number) Center(child: Text(ltr(number))),
          if (countryHintText(context, ref, number) case final String hint)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: Text(
                  hint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                icon: const Icon(Icons.call),
                label: Text(context.l10n.call),
                onPressed: () => placeCall(ref, number),
              ),
              if (ref.watch(callFeaturesProvider).value?.video ?? false)
                OutlinedButton.icon(
                  icon: const Icon(Icons.videocam_outlined),
                  label: Text(context.l10n.videoCall),
                  onPressed: () => placeCall(ref, number, video: true),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.alarm_add_outlined),
                label: Text(context.l10n.callBackLater),
                onPressed: () => showCallBackSheet(
                  context,
                  ref,
                  number: number,
                  contact: contact,
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.message_outlined),
                label: Text(context.l10n.message),
                onPressed: () => sendMessage(number),
              ),
              if (contact == null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt_outlined),
                  label: Text(context.l10n.addToContacts),
                  onPressed: () => ref.read(telecomProvider).addContact(number),
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.tune),
                  label: Text(context.l10n.callSettings),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ContactCallSettingsPage(contact: contact),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.block),
                label: Text(context.l10n.block),
                onPressed: () => confirmBlock(context, ref, number),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DialShortcutTiles(
            numbers: contact?.phones.isNotEmpty == true
                ? contact!.phones
                : <String>[number],
            contact: contact,
          ),
          const SizedBox(height: 8),
          const Divider(),
          if (calls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                personSummary(context.l10n, calls),
                style: theme.textTheme.titleSmall,
              ),
            ),
          if (calls.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.noCallsInHistory,
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
              title: Row(
                children: <Widget>[
                  Flexible(child: Text(callTypeIcon(c.type).$2)),
                  if (c.isPrivate) ...<Widget>[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      semanticLabel: context.l10n.privateCallLog,
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                context.l10n.dayAndTime(
                  dayLabel(c.date, DateTime.now()),
                  TimeOfDay.fromDateTime(c.date).format(context),
                ),
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
        title: Text(d.l10n.deleteCallsQuestion(calls.length)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: Text(d.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(d.l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(privateCallsServiceProvider).delete(calls);
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// "1:05", "12 sec", "1:02:03".
String formatDuration(Duration d) {
  if (d.inSeconds < 60) return currentL10n.durationSeconds(d.inSeconds);
  String two(int n) => n.toString().padLeft(2, '0');
  final String ms = '${d.inMinutes % 60}:${two(d.inSeconds % 60)}';
  return d.inHours > 0
      ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
      : ms;
}

(IconData, String) callTypeIcon(CallType t) {
  final AppL10n l = currentL10n;
  return switch (t) {
    CallType.incoming => (Icons.call_received, l.incoming),
    CallType.outgoing => (Icons.call_made, l.outgoing),
    CallType.missed => (Icons.call_missed, l.missed),
    CallType.rejected => (Icons.call_end, l.declined),
    CallType.blocked => (Icons.block, l.blocked),
    CallType.voicemail => (Icons.voicemail, l.voicemail),
    CallType.other => (Icons.call, l.call),
  };
}
