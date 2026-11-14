import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:intl/intl.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/call_details_page.dart';
import 'package:zerotrust_phone/services/private_calls.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/call_stats.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';

/// The longer history the stats read (Recents shows the latest 500), with
/// private calls from the vault (P23).
final statsCallsProvider = FutureProvider<List<CallLogEntry>>((ref) async {
  final List<CallLogEntry> shared = await ref
      .watch(telecomProvider)
      .callLog(limit: 5000);
  ref.watch(callLogProvider); // Refreshes with Recents.
  final List<BackedUpCall> private =
      ref.watch(privateCallsProvider).value ?? const <BackedUpCall>[];
  return mergeCalls(shared, private);
});

/// "2 h 14 min", "14 min", "45 sec".
String talkTime(AppL10n l, Duration d) {
  if (d.inMinutes == 0) return l.durationSeconds(d.inSeconds);
  if (d.inHours == 0) return l.talkMinutes(d.inMinutes);
  return l.talkHoursMinutes(d.inHours, d.inMinutes % 60);
}

/// Call stats (P28): totals, the last 8 weeks and the people I talk to
/// most. Worked out on the phone; nothing leaves it.
class CallStatsPage extends ConsumerStatefulWidget {
  const CallStatsPage({super.key, this.now});

  /// Fixed time, for tests.
  final DateTime? now;

  @override
  ConsumerState<CallStatsPage> createState() => _CallStatsPageState();
}

class _CallStatsPageState extends ConsumerState<CallStatsPage> {
  StatsPeriod _period = StatsPeriod.month;

  @override
  Widget build(BuildContext context) {
    final AppL10n l = context.l10n;
    final AsyncValue<List<CallLogEntry>> log = ref.watch(statsCallsProvider);
    final ContactDirectory directory = ref.watch(contactDirectoryProvider);
    // Sunday in Israel and the US, Monday in much of Europe.
    final int firstDay =
        (MaterialLocalizations.of(context).firstDayOfWeekIndex + 6) % 7 + 1;

    return Scaffold(
      appBar: AppBar(title: Text(l.callStats)),
      body: log.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text(l.couldntReadHistory('$e'))),
        data: (List<CallLogEntry> calls) {
          final CallStats s = CallStats.compute(
            calls,
            now: widget.now ?? DateTime.now(),
            period: _period,
            directory: directory,
            firstDayOfWeek: firstDay,
          );
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<StatsPeriod>(
                  showSelectedIcon: false,
                  segments: <ButtonSegment<StatsPeriod>>[
                    ButtonSegment<StatsPeriod>(
                      value: StatsPeriod.week,
                      label: Text(l.statsWeek),
                    ),
                    ButtonSegment<StatsPeriod>(
                      value: StatsPeriod.month,
                      label: Text(l.statsMonth),
                    ),
                    ButtonSegment<StatsPeriod>(
                      value: StatsPeriod.year,
                      label: Text(l.statsYear),
                    ),
                    ButtonSegment<StatsPeriod>(
                      value: StatsPeriod.all,
                      label: Text(l.filterAll),
                    ),
                  ],
                  selected: <StatsPeriod>{_period},
                  onSelectionChanged: (Set<StatsPeriod> v) =>
                      setState(() => _period = v.first),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: <Widget>[
                    _TileRow(<Widget>[
                      _Tile(
                        label: l.statsCalls,
                        value: '${s.calls}',
                        detail: l.statsInOut(s.incoming, s.outgoing),
                      ),
                      _Tile(label: l.statsTalkTime, value: talkTime(l, s.talk)),
                    ]),
                    _TileRow(<Widget>[
                      _Tile(label: l.missed, value: '${s.missed}'),
                      _Tile(
                        label: l.statsAverageCall,
                        value: talkTime(l, s.averageCall),
                      ),
                    ]),
                  ],
                ),
              ),
              _Header(l.statsLastWeeks),
              _WeekBars(weeks: s.weeks),
              _Header(l.statsMostTalked),
              if (s.people.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.noCallsYet, textAlign: TextAlign.center),
                ),
              for (final PersonStats p in s.people.take(10))
                ListTile(
                  leading: ContactAvatar(label: p.contact?.name ?? ''),
                  title: Text(p.contact?.name ?? ltr(p.number)),
                  subtitle: Text(
                    l.statsPersonLine(p.calls, talkTime(l, p.talk)),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CallDetailsPage(number: p.number),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l.statsPrivacy,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}

/// Two tiles side by side, as tall as the taller one.
class _TileRow extends StatelessWidget {
  const _TileRow(this.tiles);
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[for (final Widget t in tiles) Expanded(child: t)],
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.detail});
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card.filled(
      margin: const EdgeInsets.all(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: theme.textTheme.labelMedium, maxLines: 1),
            Text(value, style: theme.textTheme.titleLarge, maxLines: 1),
            if (detail != null)
              Text(detail!, style: theme.textTheme.bodySmall, maxLines: 1),
          ],
        ),
      ),
    );
  }
}

/// Talk time per week as bars, newest on the end side.
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.weeks});
  final List<WeekStats> weeks;

  @override
  Widget build(BuildContext context) {
    final AppL10n l = context.l10n;
    final ThemeData theme = Theme.of(context);
    final int most = weeks.fold<int>(
      0,
      (int m, WeekStats w) => w.talk.inSeconds > m ? w.talk.inSeconds : m,
    );
    const double height = 120;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final WeekStats w in weeks)
            Expanded(
              child: Semantics(
                label: l.statsWeekBar(
                  DateFormat('d MMM').format(w.start),
                  w.calls,
                  talkTime(l, w.talk),
                ),
                excludeSemantics: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('${w.calls}', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Container(
                      key: ValueKey<String>(
                        'week-bar-${w.start.toIso8601String()}',
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: most == 0
                          ? 2
                          : 2 + (height - 2) * w.talk.inSeconds / most,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d/M').format(w.start),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One line for a person's call details page: "37 calls · 2 h 14 min".
String personSummary(AppL10n l, List<CallLogEntry> calls) {
  final Duration talk = calls.fold<Duration>(
    Duration.zero,
    (Duration t, CallLogEntry e) => t + e.duration,
  );
  return l.statsPersonLine(calls.length, talkTime(l, talk));
}
