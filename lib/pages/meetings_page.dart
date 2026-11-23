import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/calendar/meeting_guard.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// Settings > Calendar and calls (P26): meetings with a contact shown on
/// their calls, and what happens to calls during a meeting.
class MeetingsPage extends ConsumerStatefulWidget {
  const MeetingsPage({super.key});

  @override
  ConsumerState<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends ConsumerState<MeetingsPage> {
  late final TextEditingController _message = TextEditingController(
    text: ref.read(meetingGuardProvider).message ?? '',
  );

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _set(MeetingGuard next) =>
      ref.read(meetingGuardProvider.notifier).set(next);

  @override
  Widget build(BuildContext context) {
    final AppL10n l = context.l10n;
    final MeetingGuard g = ref.watch(meetingGuardProvider);
    final Color muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: Text(l.calendarAndCalls)),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(l.calendarAndCallsBody),
          ),
          SwitchListTile(
            key: const ValueKey<String>('show-meetings'),
            secondary: const Icon(Icons.event_outlined),
            title: Text(l.showMeetings),
            subtitle: Text(l.showMeetingsBody),
            value: g.showMeetings,
            onChanged: (bool on) => _set(g.copyWith(showMeetings: on)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: Text(l.callsDuringMeetings),
          ),
          RadioGroup<InMeeting>(
            groupValue: g.mode,
            onChanged: (InMeeting? m) {
              if (m != null) _set(g.copyWith(mode: m));
            },
            child: Column(
              children: <Widget>[
                RadioListTile<InMeeting>(
                  key: const ValueKey<String>('meeting-ring'),
                  value: InMeeting.ring,
                  title: Text(l.inMeetingRing),
                ),
                RadioListTile<InMeeting>(
                  key: const ValueKey<String>('meeting-silence'),
                  value: InMeeting.silence,
                  title: Text(l.inMeetingSilence),
                  subtitle: Text(l.inMeetingSilenceBody),
                ),
                RadioListTile<InMeeting>(
                  key: const ValueKey<String>('meeting-decline'),
                  value: InMeeting.decline,
                  title: Text(l.inMeetingDecline),
                  subtitle: Text(l.inMeetingDeclineBody),
                ),
              ],
            ),
          ),
          if (g.mode == InMeeting.decline)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                key: const ValueKey<String>('meeting-message'),
                controller: _message,
                maxLength: 160,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: l.inMeetingMessage,
                  hintText: l.inMeetingDefaultMessage,
                ),
                onChanged: (String v) => _set(
                  g.copyWith(message: () => v.trim().isEmpty ? null : v),
                ),
              ),
            ),
          if (g.mode != InMeeting.ring)
            SwitchListTile(
              key: const ValueKey<String>('meeting-repeat'),
              title: Text(l.letRepeatCallersRing),
              subtitle: Text(l.letRepeatCallersRingBody),
              value: g.letRepeatCallersRing,
              onChanged: (bool on) =>
                  _set(g.copyWith(letRepeatCallersRing: on)),
            ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.info_outline, color: muted),
            subtitle: Text(l.calendarAndCallsLimits),
          ),
        ],
      ),
    );
  }
}
