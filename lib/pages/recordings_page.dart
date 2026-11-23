import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/recording_settings_page.dart';
import 'package:zerotrust_phone/services/notes_bridge.dart';
import 'package:zerotrust_phone/services/recordings.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

/// Recorded calls (P19) and visual voicemail (P21), with transcripts made
/// on the phone (P20, P21) that can be saved to ZT Notes.
class RecordingsPage extends ConsumerStatefulWidget {
  const RecordingsPage({super.key});

  @override
  ConsumerState<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends ConsumerState<RecordingsPage> {
  late final Telecom _telecom = ref.read(telecomProvider);
  List<CallRecording>? _recordings;
  List<Voicemail>? _voicemails;

  /// What's playing: `r:id` or `v:id`.
  String? _playing;

  /// What's being transcribed, same keys.
  String? _transcribing;

  @override
  void initState() {
    super.initState();
    _telecom.playbackDone.addListener(_onPlaybackDone);
    _load();
  }

  @override
  void dispose() {
    _telecom.playbackDone.removeListener(_onPlaybackDone);
    if (_playing != null) _telecom.stopPlayback().ignore();
    if (_transcribing != null) _telecom.cancelTranscript().ignore();
    super.dispose();
  }

  void _onPlaybackDone() {
    if (mounted) setState(() => _playing = null);
  }

  Future<void> _load() async {
    final List<CallRecording> recordings =
        <CallRecording>[
          for (final Map<Object?, Object?> m in await _telecom.recordings())
            ?CallRecording.fromMap(m),
        ]..sort(
          (CallRecording a, CallRecording b) =>
              b.startedAt.compareTo(a.startedAt),
        );
    final List<Voicemail> voicemails = <Voicemail>[
      for (final Map<Object?, Object?> m in await _telecom.voicemails())
        ?Voicemail.fromMap(m),
    ];
    if (!mounted) return;
    setState(() {
      _recordings = recordings;
      _voicemails = voicemails;
    });
  }

  Future<void> _togglePlay(String key, Future<void> Function() play) async {
    if (_playing == key) {
      await _telecom.stopPlayback();
      setState(() => _playing = null);
      return;
    }
    setState(() => _playing = key);
    await play();
  }

  Future<void> _transcribe({
    required String key,
    required bool voicemail,
    required String who,
    required String number,
    required DateTime at,
    required Duration length,
    required Future<Map<Object?, Object?>> Function(String language) run,
    String? id,
  }) async {
    final String language = ref.read(recordingSettingsProvider).language;
    _telecom.transcriptProgress.value = 0;
    setState(() => _transcribing = key);
    final Transcript t = Transcript.from(await run(language));
    if (!mounted) return;
    setState(() => _transcribing = null);
    final AppL10n l = context.l10n;
    switch (t) {
      case TranscriptNoModel():
        final bool? open = await showDialog<bool>(
          context: context,
          builder: (BuildContext d) => AlertDialog(
            title: Text(d.l10n.transcriptNeedsModel),
            content: Text(d.l10n.transcriptNeedsModelBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(d).pop(false),
                child: Text(d.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(d).pop(true),
                child: Text(d.l10n.speechModels),
              ),
            ],
          ),
        );
        if (open == true && mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const RecordingSettingsPage(),
            ),
          );
        }
      case TranscriptNoAudio() || TranscriptFailed():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t is TranscriptNoAudio ? l.transcriptNoAudio : l.transcriptFailed,
            ),
          ),
        );
      case TranscriptText(:final String text):
        await _showTranscript(
          text: text,
          note: transcriptNote(
            l: l,
            voicemail: voicemail,
            who: who,
            number: number,
            at: at,
            length: length,
            text: text,
          ),
          onSaved: id == null ? null : () => _telecom.markTranscribed(id),
        );
    }
  }

  Future<void> _showTranscript({
    required String text,
    required ({String title, String body}) note,
    Future<void> Function()? onSaved,
  }) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(note.title, style: Theme.of(sheet).textTheme.titleMedium),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheet).height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    key: const ValueKey<String>('transcript-text'),
                    text.isEmpty ? sheet.l10n.transcriptEmpty : text,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sheet.l10n.transcriptMadeOnPhone,
                style: Theme.of(sheet).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey<String>('transcript-copy'),
                      onPressed: () => Navigator.of(sheet).pop('copy'),
                      icon: const Icon(Icons.copy),
                      label: Text(sheet.l10n.copy),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey<String>('transcript-save'),
                      onPressed: () => Navigator.of(sheet).pop('save'),
                      icon: const Icon(Icons.note_add_outlined),
                      label: Text(sheet.l10n.saveToNotes),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    final AppL10n l = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: text));
      return;
    }
    try {
      await ref
          .read(notesBridgeProvider)
          .add(title: note.title, body: note.body);
      await onSaved?.call();
      messenger.showSnackBar(SnackBar(content: Text(l.savedToNotes)));
      await _load();
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l.notesSaveFailed)));
    }
  }

  Future<void> _delete(CallRecording r) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text(d.l10n.deleteRecordingQuestion),
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
    if (_playing == 'r:${r.id}') await _telecom.stopPlayback();
    await _telecom.deleteRecording(r.id);
    await _load();
  }

  Widget _busy() => ValueListenableBuilder<int>(
    valueListenable: _telecom.transcriptProgress,
    builder: (BuildContext _, int percent, Widget? _) => SizedBox.square(
      dimension: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        value: percent > 0 ? percent / 100 : null,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final AppL10n l = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = l.localeName;
    final List<CallRecording>? recordings = _recordings;
    final List<Voicemail>? voicemails = _voicemails;
    String when(DateTime t) => DateFormat.yMMMd(locale).add_Hm().format(t);
    String length(Duration d) =>
        '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.recordingsAndVoicemail),
        actions: <Widget>[
          IconButton(
            tooltip: l.recordingSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RecordingSettingsPage(),
              ),
            ),
          ),
        ],
      ),
      body: recordings == null || voicemails == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: <Widget>[
                  header(l.recordedCalls),
                  if (recordings.isEmpty)
                    ListTile(
                      key: const ValueKey<String>('no-recordings'),
                      title: Text(l.noRecordings),
                      subtitle: Text(l.noRecordingsBody),
                    ),
                  for (final CallRecording r in recordings)
                    ListTile(
                      key: ValueKey<String>('recording-${r.id}'),
                      leading: IconButton(
                        tooltip: _playing == 'r:${r.id}' ? l.stop : l.play,
                        icon: Icon(
                          _playing == 'r:${r.id}'
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outline,
                        ),
                        onPressed: () => _togglePlay(
                          'r:${r.id}',
                          () => _telecom.playRecording(r.id),
                        ),
                      ),
                      title: Text(r.name ?? ltr(r.number)),
                      subtitle: Text(
                        '${when(r.startedAt)} · ${length(r.length)}'
                        '${r.transcribed ? ' · ${l.inNotes}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (_transcribing == 'r:${r.id}')
                            _busy()
                          else
                            IconButton(
                              key: ValueKey<String>('transcribe-${r.id}'),
                              tooltip: l.transcribe,
                              icon: const Icon(Icons.subject),
                              onPressed: _transcribing != null
                                  ? null
                                  : () => _transcribe(
                                      key: 'r:${r.id}',
                                      voicemail: false,
                                      who: r.who,
                                      number: r.number,
                                      at: r.startedAt,
                                      length: r.length,
                                      id: r.id,
                                      run: (String lang) => _telecom
                                          .transcribeRecording(r.id, lang),
                                    ),
                            ),
                          IconButton(
                            tooltip: l.delete,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(r),
                          ),
                        ],
                      ),
                    ),
                  header(l.voicemail),
                  if (voicemails.isEmpty)
                    ListTile(
                      key: const ValueKey<String>('no-voicemail'),
                      title: Text(l.noVisualVoicemail),
                      subtitle: Text(l.noVisualVoicemailBody),
                    ),
                  for (final Voicemail v in voicemails)
                    ListTile(
                      key: ValueKey<String>('voicemail-${v.id}'),
                      leading: IconButton(
                        tooltip: _playing == 'v:${v.id}' ? l.stop : l.play,
                        icon: Icon(
                          _playing == 'v:${v.id}'
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outline,
                        ),
                        onPressed: !v.hasAudio
                            ? null
                            : () => _togglePlay('v:${v.id}', () async {
                                if (!await _telecom.playVoicemail(v.id) &&
                                    mounted) {
                                  setState(() => _playing = null);
                                }
                              }),
                      ),
                      title: Text(
                        v.name ??
                            (v.number.isEmpty
                                ? l.privateNumber
                                : ltr(v.number)),
                        style: v.read
                            ? null
                            : const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        v.carrierText ?? '${when(v.at)} · ${length(v.length)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: _transcribing == 'v:${v.id}'
                          ? _busy()
                          : IconButton(
                              key: ValueKey<String>('transcribe-v${v.id}'),
                              tooltip: l.transcribe,
                              icon: const Icon(Icons.subject),
                              onPressed: !v.hasAudio || _transcribing != null
                                  ? null
                                  : () => _transcribe(
                                      key: 'v:${v.id}',
                                      voicemail: true,
                                      who: v.who.isEmpty
                                          ? l.privateNumber
                                          : v.who,
                                      number: v.number,
                                      at: v.at,
                                      length: v.length,
                                      run: (String lang) => _telecom
                                          .transcribeVoicemail(v.id, lang),
                                    ),
                            ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
