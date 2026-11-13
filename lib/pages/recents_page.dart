import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/pages/call_actions.dart';
import 'package:zerotrust_phone/pages/call_back_sheet.dart';
import 'package:zerotrust_phone/pages/call_details_page.dart';
import 'package:zerotrust_phone/pages/call_stats_page.dart';
import 'package:zerotrust_phone/services/private_calls.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// Back-to-back calls with one number, shown as one row.
class CallGroup {
  CallGroup(this.calls);
  final List<CallLogEntry> calls;
  CallLogEntry get latest => calls.first;

  static List<CallGroup> group(List<CallLogEntry> log) {
    final List<CallGroup> out = <CallGroup>[];
    for (final CallLogEntry e in log) {
      final CallGroup? last = out.isEmpty ? null : out.last;
      if (last != null &&
          PhoneNumbers.same(last.latest.number, e.number) &&
          _sameDay(last.latest.date, e.date)) {
        last.calls.add(e);
      } else {
        out.add(CallGroup(<CallLogEntry>[e]));
      }
    }
    return out;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Which calls Recents shows (P4).
enum RecentsFilter {
  all,
  missed,
  incoming,
  outgoing,
  blocked;

  /// The chip's name in the app's language.
  String label(AppL10n l) => switch (this) {
    all => l.filterAll,
    missed => l.missed,
    incoming => l.incoming,
    outgoing => l.outgoing,
    blocked => l.blocked,
  };

  /// What an empty list says under this filter.
  String empty(AppL10n l) => switch (this) {
    all => l.noCallsYet,
    missed => l.noMissedCalls,
    incoming => l.noIncomingCalls,
    outgoing => l.noOutgoingCalls,
    blocked => l.noBlockedCalls,
  };

  bool accepts(CallLogEntry e) => switch (this) {
    RecentsFilter.all => true,
    RecentsFilter.missed => e.type == CallType.missed,
    RecentsFilter.incoming => e.type == CallType.incoming,
    RecentsFilter.outgoing => e.type == CallType.outgoing,
    RecentsFilter.blocked =>
      e.type == CallType.blocked || e.type == CallType.rejected,
  };
}

/// Calls matching [query] by contact name, saved name or number.
List<CallLogEntry> filterCalls(
  List<CallLogEntry> log,
  ContactDirectory directory, {
  String query = '',
  RecentsFilter filter = RecentsFilter.all,
}) {
  final String q = query.trim().toLowerCase();
  final String digits = q.replaceAll(RegExp(r'[^0-9]'), '');
  return log.where((CallLogEntry e) {
    if (!filter.accepts(e)) return false;
    if (q.isEmpty) return true;
    final String name = directory.lookup(e.number)?.name ?? e.cachedName ?? '';
    if (name.toLowerCase().contains(q)) return true;
    return digits.isNotEmpty &&
        PhoneNumbers.normalize(e.number).contains(digits);
  }).toList();
}

class RecentsPage extends ConsumerStatefulWidget {
  const RecentsPage({super.key, this.query = ''});

  final String query;

  @override
  ConsumerState<RecentsPage> createState() => _RecentsPageState();
}

class _RecentsPageState extends ConsumerState<RecentsPage> {
  RecentsFilter _filter = RecentsFilter.all;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CallLogEntry>> log = ref.watch(allCallsProvider);
    final ContactDirectory directory = ref.watch(contactDirectoryProvider);

    final Widget chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: <Widget>[
          for (final RecentsFilter f in RecentsFilter.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(f.label(context.l10n)),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
              ),
            ),
          // P28.
          ActionChip(
            avatar: const Icon(Icons.insights_outlined, size: 18),
            label: Text(context.l10n.callStats),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CallStatsPage()),
            ),
          ),
        ],
      ),
    );

    return log.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => _Empty(
        icon: Icons.history,
        text: context.l10n.couldntReadHistory('$e'),
      ),
      data: (List<CallLogEntry> entries) {
        final List<CallLogEntry> shown = filterCalls(
          entries,
          directory,
          query: widget.query,
          filter: _filter,
        );
        final List<CallGroup> groups = CallGroup.group(shown);
        return Column(
          children: <Widget>[
            chips,
            // P25: reminders to call someone back.
            const CallBackList(),
            Expanded(
              child: groups.isEmpty
                  ? _Empty(
                      icon: widget.query.isEmpty
                          ? Icons.history
                          : Icons.search_off,
                      text: widget.query.isNotEmpty
                          ? context.l10n.noCallsMatch(widget.query)
                          : _filter.empty(context.l10n),
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(callLogProvider.future),
                      child: ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (BuildContext context, int i) => _CallRow(
                          group: groups[i],
                          contact: directory.lookup(groups[i].latest.number),
                          showDay:
                              i == 0 ||
                              !CallGroup._sameDay(
                                groups[i - 1].latest.date,
                                groups[i].latest.date,
                              ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _CallRow extends ConsumerWidget {
  const _CallRow({required this.group, this.contact, required this.showDay});

  final CallGroup group;
  final PhoneContact? contact;
  final bool showDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CallLogEntry call = group.latest;
    final ThemeData theme = Theme.of(context);
    final String number = call.number;
    final String title =
        contact?.name ??
        (call.cachedName?.isNotEmpty == true
            ? call.cachedName!
            : (number.isEmpty ? context.l10n.privateNumber : ltr(number)));
    final bool missed = call.type == CallType.missed;
    final (IconData icon, String label) = callTypeIcon(call.type);
    final String count = group.calls.length > 1
        ? ' (${group.calls.length})'
        : '';
    final String when = TimeOfDay.fromDateTime(call.date).format(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showDay)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Semantics(
              header: true,
              child: Text(
                dayLabel(call.date, DateTime.now()),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ListTile(
          leading: ContactAvatar(label: contact?.name ?? call.cachedName ?? ''),
          title: Text(
            '$title$count',
            style: missed ? TextStyle(color: theme.colorScheme.error) : null,
          ),
          subtitle: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: missed
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
                semanticLabel: label,
              ),
              if (call.isPrivate) ...<Widget>[
                const SizedBox(width: 4),
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                  semanticLabel: context.l10n.privateCallLog,
                ),
              ],
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  contact != null || call.cachedName != null
                      ? '${ltr(number)} · $when'
                      : when,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          trailing: number.isEmpty
              ? null
              : IconButton(
                  tooltip: context.l10n.callName(title),
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => placeCall(ref, number),
                ),
          onTap: number.isEmpty
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CallDetailsPage(number: number),
                  ),
                ),
          onLongPress: () => _delete(context, ref),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text(
          group.calls.length == 1
              ? d.l10n.deleteThisCall
              : d.l10n.deleteCallsQuestion(group.calls.length),
        ),
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
    await ref.read(privateCallsServiceProvider).delete(group.calls);
  }
}

String dayLabel(DateTime date, DateTime now) {
  final DateTime d = DateTime(date.year, date.month, date.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  final int days = today.difference(d).inDays;
  if (days == 0) return currentL10n.today;
  if (days == 1) return currentL10n.yesterday;
  // "9 Nov" / "9 בנוב׳", in the app's language (Intl.defaultLocale).
  return date.year == now.year
      ? DateFormat('d MMM').format(date)
      : DateFormat('d MMM y').format(date);
}

class _Empty extends StatelessWidget {
  const _Empty({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class EmptyState extends _Empty {
  const EmptyState({super.key, required super.icon, required super.text});
}
