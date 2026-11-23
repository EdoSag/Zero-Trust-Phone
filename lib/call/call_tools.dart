import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerotrust_phone/call/call_state.dart';
import 'package:zerotrust_phone/services/notes_bridge.dart';
import 'package:zerotrust_phone/services/recordings.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// ZT Calendar's Android package, opened from the call screen (P27).
const String ztCalendarPackage = 'dev.sagron.zerotrustcalendar';

/// The call screen's link to Android for the tools (opening ZT Calendar,
/// texting my card). Fakeable in tests.
class CallTools {
  CallTools([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('zt_phone/call_control');
  final MethodChannel _channel;

  /// Opens ZT Calendar, after unlocking the phone. False when it's not
  /// installed.
  Future<bool> openCalendar() async =>
      await _channel.invokeMethod<bool>('openApp', {
        'package': ztCalendarPackage,
      }) ??
      false;

  /// P19: starts or stops recording call [id]. False when it couldn't
  /// start (the call screen then shows why).
  Future<bool> record(String id, bool on) async =>
      await _channel.invokeMethod<bool>('record', {'id': id, 'on': on}) ??
      false;

  /// Opens the SMS app with [text] to [number], ready to send.
  Future<bool> text(String number, String text) => launchUrl(
    Uri(
      scheme: 'smsto',
      path: number,
      queryParameters: <String, String>{'body': text},
    ),
  );
}

final callToolsProvider = Provider<CallTools>((ref) => CallTools());

/// Reads the recording switch and My card again. The call screen's engine
/// stays alive between calls, so what it loaded once would otherwise miss a
/// change made in the app since (Record not offered after recording was
/// turned on, an old card still sent).
void reloadCallToolSettings(ProviderContainer container) {
  container
    ..invalidate(recordingSettingsProvider)
    ..invalidate(myCardProvider);
}

/// P27: in-call tools. A note (kept on the phone until ZT Phone is next
/// unlocked, then saved in ZT Notes), my card by text, and ZT Calendar.
Future<void> showCallTools(BuildContext context, PhoneCall call) {
  // The sheet's own ref ends when it closes; the tools outlive it.
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  reloadCallToolSettings(container);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheet) => Consumer(
      builder: (BuildContext _, WidgetRef ref, Widget? _) {
        final AppL10n l = sheet.l10n;
        final String? card = ref.watch(myCardProvider).value;
        final bool canRecord =
            ref.watch(recordingSettingsProvider).recordCalls &&
            call.state == CallState.active;
        final bool recording = call.recordingSince != null;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (canRecord || recording)
                ListTile(
                  key: const ValueKey<String>('tool-record'),
                  leading: Icon(
                    recording
                        ? Icons.stop_circle_outlined
                        : Icons.fiber_manual_record_outlined,
                  ),
                  title: Text(recording ? l.stopRecording : l.recordCall),
                  subtitle: Text(
                    recording ? l.recordingKept : l.recordCallBody,
                  ),
                  onTap: () {
                    Navigator.of(sheet).pop();
                    container
                        .read(callToolsProvider)
                        .record(call.id, !recording)
                        .ignore();
                  },
                ),
              ListTile(
                key: const ValueKey<String>('tool-note'),
                leading: const Icon(Icons.edit_note),
                title: Text(l.callNote),
                subtitle: Text(l.callNoteBody),
                onTap: () async {
                  Navigator.of(sheet).pop();
                  await _writeNote(context, container, call);
                },
              ),
              ListTile(
                key: const ValueKey<String>('tool-card'),
                leading: const Icon(Icons.contact_page_outlined),
                title: Text(l.textMyCard),
                subtitle: Text(
                  card == null ? l.myCardNotSet : l.textMyCardBody,
                ),
                enabled: card != null,
                onTap: card == null
                    ? null
                    : () {
                        Navigator.of(sheet).pop();
                        container
                            .read(callToolsProvider)
                            .text(call.number, card);
                      },
              ),
              ListTile(
                key: const ValueKey<String>('tool-calendar'),
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(l.openCalendar),
                subtitle: Text(l.openCalendarBody),
                onTap: () async {
                  Navigator.of(sheet).pop();
                  final bool opened = await container
                      .read(callToolsProvider)
                      .openCalendar();
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.calendarMissing)),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _writeNote(
  BuildContext context,
  ProviderContainer container,
  PhoneCall call,
) async {
  final String? note = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheet) => _NoteSheet(title: call.title),
  );
  if (note == null || note.trim().isEmpty) return;
  await container
      .read(pendingCallNotesProvider)
      .add(
        PendingCallNote(
          number: call.number,
          name: call.name ?? '',
          at: DateTime.now(),
          text: note.trim(),
        ),
      );
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.callNoteSaved)));
  }
}

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.title});
  final String title;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      0,
      16,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.l10n.callNoteTitle(widget.title),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey<String>('note-text'),
          controller: _text,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: context.l10n.callNoteHint,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.callNoteWhere,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_text.text),
            child: Text(context.l10n.save),
          ),
        ),
      ],
    ),
  );
}
