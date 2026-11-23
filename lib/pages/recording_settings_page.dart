import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/services/recordings.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

/// Call recording (P19), transcripts to ZT Notes (P20, P21), and the speech
/// models they use. Says plainly what Android allows.
class RecordingSettingsPage extends ConsumerStatefulWidget {
  const RecordingSettingsPage({super.key});

  @override
  ConsumerState<RecordingSettingsPage> createState() =>
      _RecordingSettingsPageState();
}

class _RecordingSettingsPageState extends ConsumerState<RecordingSettingsPage> {
  late final Telecom _telecom = ref.read(telecomProvider);
  bool _loading = true;
  bool _available = true;
  List<String> _installed = const <String>[];

  /// Null when the list couldn't be downloaded.
  List<SpeechOffer>? _offers;
  String? _downloading;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_downloading != null) _telecom.cancelDownload().ignore();
    super.dispose();
  }

  Future<void> _load() async {
    final Map<Object?, Object?> m = await _telecom.speechModels();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _available = m['available'] != false;
      _installed = <String>[
        for (final Object? f
            in (m['installed'] as List<Object?>?) ?? <Object?>[])
          if (f is String) f,
      ];
      final Object? offers = m['offers'];
      _offers = offers is List<Object?>
          ? <SpeechOffer>[
              for (final Object? o in offers) ?SpeechOffer.fromMap(o),
            ]
          : null;
    });
  }

  Future<void> _setRecord(bool on) async {
    final RecordingSettingsNotifier n = ref.read(
      recordingSettingsProvider.notifier,
    );
    if (on) {
      final bool? agree = await showDialog<bool>(
        context: context,
        builder: (BuildContext d) => AlertDialog(
          title: Text(d.l10n.recordCalls),
          content: Text(d.l10n.recordCallsWarning),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: Text(d.l10n.cancel),
            ),
            FilledButton(
              key: const ValueKey<String>('record-agree'),
              onPressed: () => Navigator.of(d).pop(true),
              child: Text(d.l10n.turnOn),
            ),
          ],
        ),
      );
      if (agree != true) return;
      if (!await _telecom.requestMicrophone()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.microphoneNeeded)),
          );
        }
        return;
      }
    }
    await n.set(ref.read(recordingSettingsProvider).copyWith(recordCalls: on));
  }

  Future<void> _download(SpeechOffer o) async {
    setState(() => _downloading = o.file);
    final String result = await _telecom.downloadModel(o.file);
    if (!mounted) return;
    setState(() => _downloading = null);
    final AppL10n l = context.l10n;
    final String? message = switch (result) {
      'OK' || 'CANCELLED' => null,
      'NO_SPACE' => l.modelNoSpace,
      'NO_CONNECTION' => l.modelNoConnection,
      _ => l.modelFailed,
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    await _load();
  }

  static String size(int bytes) => '${(bytes / (1 << 20)).round()} MB';

  @override
  Widget build(BuildContext context) {
    final AppL10n l = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RecordingSettings s = ref.watch(recordingSettingsProvider);
    final RecordingSettingsNotifier n = ref.read(
      recordingSettingsProvider.notifier,
    );
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
    final List<SpeechOffer>? offers = _offers;
    return Scaffold(
      appBar: AppBar(title: Text(l.recordingSettings)),
      body: ListView(
        children: <Widget>[
          SwitchListTile(
            key: const ValueKey<String>('record-calls'),
            secondary: const Icon(Icons.fiber_manual_record_outlined),
            title: Text(l.recordCalls),
            subtitle: Text(l.recordCallsBody),
            isThreeLine: true,
            value: s.recordCalls,
            onChanged: _setRecord,
          ),
          SwitchListTile(
            key: const ValueKey<String>('save-transcripts'),
            secondary: const Icon(Icons.note_add_outlined),
            title: Text(l.saveTranscripts),
            subtitle: Text(l.saveTranscriptsBody),
            isThreeLine: true,
            value: s.saveTranscripts,
            onChanged: s.recordCalls
                ? (bool on) => n.set(s.copyWith(saveTranscripts: on))
                : null,
          ),
          header(l.transcriptLanguage),
          RadioGroup<String>(
            groupValue: s.language,
            onChanged: (String? v) {
              if (v != null) n.set(s.copyWith(language: v));
            },
            child: Column(
              children: <Widget>[
                for (final (String code, String label) in <(String, String)>[
                  ('auto', l.languageAuto),
                  ('he', 'עברית'),
                  ('en', 'English'),
                ])
                  RadioListTile<String>(
                    key: ValueKey<String>('lang-$code'),
                    value: code,
                    title: Text(label),
                  ),
              ],
            ),
          ),
          header(l.speechModels),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...<Widget>[
            if (!_available)
              ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(l.transcriptsUnavailable),
              ),
            for (final String f in _installed)
              ListTile(
                key: ValueKey<String>('model-$f'),
                leading: const Icon(Icons.check_circle_outline),
                title: Text(
                  offers
                          ?.where((SpeechOffer o) => o.file == f)
                          .firstOrNull
                          ?.label(l.localeName) ??
                      f,
                ),
                subtitle: Text(l.modelOnPhone),
                trailing: IconButton(
                  tooltip: l.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await _telecom.deleteModel(f);
                    await _load();
                  },
                ),
              ),
            if (offers == null)
              ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: Text(l.modelNoConnection),
                trailing: IconButton(
                  tooltip: l.retry,
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                ),
              )
            else
              for (final SpeechOffer o in offers)
                if (!_installed.contains(o.file))
                  ListTile(
                    key: ValueKey<String>('offer-${o.file}'),
                    leading: const Icon(Icons.download_outlined),
                    title: Text(o.label(l.localeName)),
                    subtitle: _downloading == o.file
                        ? ValueListenableBuilder<(String, int)?>(
                            valueListenable: _telecom.modelProgress,
                            builder:
                                (BuildContext _, (String, int)? p, Widget? _) =>
                                    LinearProgressIndicator(
                                      value: p == null || p.$1 != o.file
                                          ? null
                                          : (p.$2 / o.bytes).clamp(0.0, 1.0),
                                    ),
                          )
                        : Text(size(o.bytes)),
                    trailing: _downloading == o.file
                        ? IconButton(
                            tooltip: l.cancel,
                            icon: const Icon(Icons.close),
                            onPressed: _telecom.cancelDownload,
                          )
                        : null,
                    onTap: _downloading == null ? () => _download(o) : null,
                  ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.transcriptsExplain, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
