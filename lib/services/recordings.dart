import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/services/notes_bridge.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

/// Call recording and transcripts (P19, P20, P21), on this phone only.
class RecordingSettings {
  const RecordingSettings({
    this.recordCalls = false,
    this.saveTranscripts = false,
    this.language = 'auto',
  });

  /// Shows "Record call" on the call screen. Off by default.
  final bool recordCalls;

  /// Recorded calls are transcribed on the phone and saved to ZT Notes
  /// the next time ZT Phone is unlocked.
  final bool saveTranscripts;

  /// A Whisper language code, or "auto".
  final String language;

  RecordingSettings copyWith({
    bool? recordCalls,
    bool? saveTranscripts,
    String? language,
  }) => RecordingSettings(
    recordCalls: recordCalls ?? this.recordCalls,
    saveTranscripts: saveTranscripts ?? this.saveTranscripts,
    language: language ?? this.language,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'record': recordCalls,
    'save': saveTranscripts,
    'language': language,
  };

  static RecordingSettings fromJson(Map<String, Object?> j) =>
      RecordingSettings(
        recordCalls: j['record'] == true,
        saveTranscripts: j['save'] == true,
        language: j['language'] as String? ?? 'auto',
      );
}

final recordingSettingsProvider =
    NotifierProvider<RecordingSettingsNotifier, RecordingSettings>(
      RecordingSettingsNotifier.new,
    );

class RecordingSettingsNotifier extends Notifier<RecordingSettings> {
  static const String key = 'recording_settings';
  late Future<void> loaded;

  @override
  RecordingSettings build() {
    loaded = _load();
    return const RecordingSettings();
  }

  Future<void> _load() async {
    try {
      final String? raw = await ref.read(ztPreferencesStoreProvider).read(key);
      if (raw != null) {
        state = RecordingSettings.fromJson(
          (jsonDecode(raw) as Map<Object?, Object?>).cast<String, Object?>(),
        );
      }
    } on Object {
      // Damaged: the defaults.
    }
  }

  Future<void> set(RecordingSettings value) async {
    await loaded;
    state = value;
    await ref
        .read(ztPreferencesStoreProvider)
        .write(key, jsonEncode(value.toJson()));
  }
}

/// A recorded call (the sound stays sealed on the Android side).
class CallRecording {
  const CallRecording({
    required this.id,
    required this.number,
    required this.name,
    required this.startedAt,
    required this.length,
    required this.transcribed,
  });

  final String id;
  final String number;
  final String? name;
  final DateTime startedAt;
  final Duration length;
  final bool transcribed;

  String get who => name ?? number;

  static CallRecording? fromMap(Map<Object?, Object?> m) {
    final Object? id = m['id'];
    if (id is! String || id.isEmpty) return null;
    return CallRecording(
      id: id,
      number: m['number'] as String? ?? '',
      name: m['name'] as String?,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (m['startedAt'] as num?)?.toInt() ?? 0,
      ),
      length: Duration(milliseconds: (m['millis'] as num?)?.toInt() ?? 0),
      transcribed: m['transcribed'] == true,
    );
  }
}

/// A visual voicemail message from Android's voicemail store.
class Voicemail {
  const Voicemail({
    required this.id,
    required this.number,
    required this.name,
    required this.at,
    required this.length,
    required this.hasAudio,
    required this.read,
    this.carrierText,
  });

  final int id;
  final String number;
  final String? name;
  final DateTime at;
  final Duration length;
  final bool hasAudio;
  final bool read;

  /// A transcript the carrier sent with the message, if any.
  final String? carrierText;

  String get who => name ?? number;

  static Voicemail? fromMap(Map<Object?, Object?> m) {
    final Object? id = m['id'];
    if (id is! num) return null;
    final String? text = (m['carrierText'] as String?)?.trim();
    return Voicemail(
      id: id.toInt(),
      number: m['number'] as String? ?? '',
      name: m['name'] as String?,
      at: DateTime.fromMillisecondsSinceEpoch(
        (m['date'] as num?)?.toInt() ?? 0,
      ),
      length: Duration(seconds: (m['seconds'] as num?)?.toInt() ?? 0),
      hasAudio: m['hasAudio'] == true,
      read: m['read'] == true,
      carrierText: text == null || text.isEmpty ? null : text,
    );
  }
}

/// A downloadable speech model (ZT Keyboard's list).
class SpeechOffer {
  const SpeechOffer({
    required this.file,
    required this.bytes,
    required this.languages,
    required this.labelEn,
    required this.labelHe,
  });

  final String file;
  final int bytes;
  final List<String> languages;
  final String labelEn;
  final String labelHe;

  String label(String locale) =>
      locale.startsWith('he') && labelHe.isNotEmpty ? labelHe : labelEn;

  static SpeechOffer? fromMap(Object? o) {
    if (o is! Map<Object?, Object?>) return null;
    final Object? file = o['file'];
    if (file is! String) return null;
    return SpeechOffer(
      file: file,
      bytes: (o['bytes'] as num?)?.toInt() ?? 0,
      languages: <String>[
        for (final Object? l
            in (o['languages'] as List<Object?>?) ?? <Object?>[])
          if (l is String) l,
      ],
      labelEn: o['labelEn'] as String? ?? file,
      labelHe: o['labelHe'] as String? ?? '',
    );
  }
}

/// What a transcript came back as.
sealed class Transcript {
  const Transcript();

  static Transcript from(Map<Object?, Object?> m) {
    final Object? text = m['text'];
    if (text is String) return TranscriptText(text);
    return switch (m['error']) {
      'noModel' => const TranscriptNoModel(),
      'noAudio' => const TranscriptNoAudio(),
      _ => const TranscriptFailed(),
    };
  }
}

class TranscriptText extends Transcript {
  const TranscriptText(this.text);
  final String text;
}

class TranscriptNoModel extends Transcript {
  const TranscriptNoModel();
}

class TranscriptNoAudio extends Transcript {
  const TranscriptNoAudio();
}

class TranscriptFailed extends Transcript {
  const TranscriptFailed();
}

/// The note a transcript becomes in ZT Notes.
({String title, String body}) transcriptNote({
  required AppL10n l,
  required bool voicemail,
  required String who,
  required String number,
  required DateTime at,
  required Duration length,
  required String text,
}) {
  final String when = DateFormat.yMMMd(l.localeName).add_Hm().format(at);
  final String minutes = l.minutesShort(
    (length.inSeconds / 60).ceil().clamp(1, 9999),
  );
  return (
    title: voicemail ? l.voicemailFrom(who) : l.callNoteTitle(who),
    body:
        '${text.isEmpty ? l.transcriptEmpty : text}\n\n'
        '$when · $number · $minutes\n${l.transcriptMadeOnPhone}',
  );
}

/// P20: recorded calls not yet transcribed go to ZT Notes, when that's on.
/// Called while ZT Phone is unlocked. Returns how many were saved.
Future<int> saveNewTranscripts({
  required Telecom telecom,
  required RecordingSettings settings,
  required NotesBridge notes,
  required AppL10n l,
}) async {
  if (!settings.saveTranscripts) return 0;
  int saved = 0;
  for (final Map<Object?, Object?> m in await telecom.recordings()) {
    final CallRecording? r = CallRecording.fromMap(m);
    if (r == null || r.transcribed) continue;
    final Transcript t = Transcript.from(
      await telecom.transcribeRecording(r.id, settings.language),
    );
    if (t is! TranscriptText) {
      // No model yet, or it failed: tried again next time.
      if (t is TranscriptNoModel) return saved;
      continue;
    }
    final ({String title, String body}) note = transcriptNote(
      l: l,
      voicemail: false,
      who: r.who,
      number: r.number,
      at: r.startedAt,
      length: r.length,
      text: t.text,
    );
    await notes.add(title: note.title, body: note.body);
    await telecom.markTranscribed(r.id);
    saved++;
  }
  return saved;
}
