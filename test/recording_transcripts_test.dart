import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/app/phone_config.dart';
import 'package:zerotrust_phone/call/call_state.dart';
import 'package:zerotrust_phone/call/call_tools.dart';
import 'package:zerotrust_phone/call/in_call_app.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/recordings_page.dart';
import 'package:zerotrust_phone/services/notes_bridge.dart';
import 'package:zerotrust_phone/services/recordings.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

/// P19 call recording, P20 call transcripts, P21 voicemail transcripts.
class FakeTelecom extends Telecom {
  FakeTelecom({this.text = 'Hi, it is Dana. Call me back.'});
  String? text;
  bool hasModel = true;
  final List<Map<Object?, Object?>> recs = <Map<Object?, Object?>>[
    <Object?, Object?>{
      'id': 'r1',
      'number': '+972541234567',
      'name': 'Dana Levi',
      'startedAt': DateTime(2026, 11, 20, 10, 5).millisecondsSinceEpoch,
      'millis': 95000,
      'transcribed': false,
    },
    <Object?, Object?>{
      'id': 'r0',
      'number': '+972507654321',
      'name': null,
      'startedAt': DateTime(2026, 11, 19, 9).millisecondsSinceEpoch,
      'millis': 30000,
      'transcribed': true,
    },
  ];
  final List<String> transcribed = <String>[];
  final List<String> marked = <String>[];

  @override
  Future<List<Map<Object?, Object?>>> recordings() async => recs;

  @override
  Future<List<Map<Object?, Object?>>> voicemails() async =>
      const <Map<Object?, Object?>>[];

  @override
  Future<Map<Object?, Object?>> transcribeRecording(
    String id,
    String language,
  ) async {
    transcribed.add('$id:$language');
    if (!hasModel) return <Object?, Object?>{'error': 'noModel'};
    return <Object?, Object?>{'text': text};
  }

  @override
  Future<void> markTranscribed(String id) async => marked.add(id);
}

class FakeNotes implements NotesBridge {
  final List<(String, String)> added = <(String, String)>[];

  @override
  Future<String> add({required String title, required String body}) async {
    added.add((title, body));
    return 'n${added.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCallControl extends CallControl {
  @override
  Stream<(String, String)> get rttText =>
      const Stream<(String, String)>.empty();
}

class FakeCallTools extends CallTools {
  final List<String> done = <String>[];
  @override
  Future<bool> record(String id, bool on) async {
    done.add('record $id $on');
    return true;
  }
}

Widget app(List overrides, Widget home) => ProviderScope(
  key: UniqueKey(),
  overrides: [...overrides],
  child: MaterialApp(
    supportedLocales: ZtLanguages.supported,
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      AppL10n.delegate,
      ...ZtLanguages.delegates,
    ],
    home: home,
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('he');
  });

  test('recording is off until turned on, and remembered', () async {
    final InMemoryPreferencesStore prefs = InMemoryPreferencesStore();
    final ProviderContainer c = ProviderContainer(
      overrides: [ztPreferencesStoreProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    await c.read(recordingSettingsProvider.notifier).loaded;
    expect(c.read(recordingSettingsProvider).recordCalls, isFalse);
    expect(c.read(recordingSettingsProvider).saveTranscripts, isFalse);
    await c
        .read(recordingSettingsProvider.notifier)
        .set(
          const RecordingSettings(
            recordCalls: true,
            saveTranscripts: true,
            language: 'he',
          ),
        );
    final ProviderContainer again = ProviderContainer(
      overrides: [ztPreferencesStoreProvider.overrideWithValue(prefs)],
    );
    addTearDown(again.dispose);
    await again.read(recordingSettingsProvider.notifier).loaded;
    expect(again.read(recordingSettingsProvider).language, 'he');
    expect(again.read(recordingSettingsProvider).recordCalls, isTrue);
  });

  test('a transcript note names the call, time and length', () {
    final ({String title, String body}) en = transcriptNote(
      l: appL10nFor(const Locale('en')),
      voicemail: true,
      who: 'Dana Levi',
      number: '+972541234567',
      at: DateTime(2026, 11, 20, 10, 5),
      length: const Duration(seconds: 95),
      text: 'Call me back.',
    );
    expect(en.title, 'Voicemail from Dana Levi');
    expect(en.body, startsWith('Call me back.\n\n'));
    expect(en.body, contains('+972541234567 · 2 min'));
    final ({String title, String body}) he = transcriptNote(
      l: appL10nFor(const Locale('he')),
      voicemail: false,
      who: 'דנה',
      number: '050',
      at: DateTime(2026, 11, 20, 10, 5),
      length: Duration.zero,
      text: '',
    );
    expect(he.body, startsWith('(לא נשמעו מילים)'));
    expect(he.body, contains('1 דק׳'));
  });

  test('new recordings go to ZT Notes when that is on', () async {
    final FakeTelecom telecom = FakeTelecom();
    final FakeNotes notes = FakeNotes();
    expect(
      await saveNewTranscripts(
        telecom: telecom,
        settings: const RecordingSettings(recordCalls: true),
        notes: notes,
        l: appL10nFor(const Locale('en')),
      ),
      0,
    );
    expect(telecom.transcribed, isEmpty);

    final int saved = await saveNewTranscripts(
      telecom: telecom,
      settings: const RecordingSettings(
        recordCalls: true,
        saveTranscripts: true,
        language: 'he',
      ),
      notes: notes,
      l: appL10nFor(const Locale('en')),
    );
    expect(saved, 1);
    // Only the one not yet transcribed, in the chosen language.
    expect(telecom.transcribed, <String>['r1:he']);
    expect(notes.added.single.$1, 'Call with Dana Levi');
    expect(notes.added.single.$2, startsWith('Hi, it is Dana. Call me back.'));
    expect(telecom.marked, <String>['r1']);
  });

  test('without a speech model nothing is marked done', () async {
    final FakeTelecom telecom = FakeTelecom()..hasModel = false;
    final FakeNotes notes = FakeNotes();
    expect(
      await saveNewTranscripts(
        telecom: telecom,
        settings: const RecordingSettings(saveTranscripts: true),
        notes: notes,
        l: appL10nFor(const Locale('en')),
      ),
      0,
    );
    expect(notes.added, isEmpty);
    expect(telecom.marked, isEmpty);
  });

  testWidgets('recordings page: transcribe and save to ZT Notes', (
    WidgetTester tester,
  ) async {
    final FakeTelecom telecom = FakeTelecom();
    final FakeNotes notes = FakeNotes();
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(<Object>[
        ztPreferencesStoreProvider.overrideWithValue(
          InMemoryPreferencesStore(),
        ),
        telecomProvider.overrideWithValue(telecom),
        notesBridgeProvider.overrideWithValue(notes),
      ], const RecordingsPage()),
    );
    await tester.pumpAndSettle();
    // Newest first, voicemail below the recordings.
    final Rect r1 = tester.getRect(
      find.byKey(const ValueKey<String>('recording-r1')),
    );
    final Rect r0 = tester.getRect(
      find.byKey(const ValueKey<String>('recording-r0')),
    );
    final Rect vm = tester.getRect(
      find.byKey(const ValueKey<String>('no-voicemail')),
    );
    expect(r1.top, lessThan(r0.top));
    expect(r0.bottom, lessThanOrEqualTo(vm.top));
    expect(find.text('Dana Levi'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('transcribe-r1')));
    await tester.pumpAndSettle();
    expect(find.text('Hi, it is Dana. Call me back.'), findsOneWidget);
    final Rect copy = tester.getRect(
      find.byKey(const ValueKey<String>('transcript-copy')),
    );
    final Rect save = tester.getRect(
      find.byKey(const ValueKey<String>('transcript-save')),
    );
    expect(copy.width, greaterThan(40));
    expect(save.left, greaterThan(copy.right));
    await tester.tap(find.byKey(const ValueKey<String>('transcript-save')));
    await tester.pumpAndSettle();
    expect(notes.added.single.$1, 'Call with Dana Levi');
    expect(telecom.marked, <String>['r1']);
    expect(find.text('Saved to ZT Notes'), findsOneWidget);
  });

  group('call screen', () {
    late StreamController<CallsSnapshot> calls;
    late FakeCallTools tools;

    Future<void> pump(
      WidgetTester tester, {
      required bool enabled,
      int? since,
    }) async {
      calls = StreamController<CallsSnapshot>();
      tools = FakeCallTools();
      final InMemoryPreferencesStore prefs = InMemoryPreferencesStore();
      if (enabled) {
        prefs.values[RecordingSettingsNotifier.key] = '{"record":true}';
      }
      await tester.binding.setSurfaceSize(const Size(400, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        app(<Object>[
          ztAppConfigProvider.overrideWithValue(phoneAppConfig),
          ztPreferencesStoreProvider.overrideWithValue(prefs),
          callControlProvider.overrideWithValue(FakeCallControl()),
          callToolsProvider.overrideWithValue(tools),
          callsProvider.overrideWith((ref) => calls.stream),
        ], const InCallScreen()),
      );
      await tester.pump();
      calls.add(
        CallsSnapshot.fromMap(<Object?, Object?>{
          'calls': <Object?>[
            <Object?, Object?>{
              'id': 'c1',
              'number': '0541234567',
              'name': 'Dana Levi',
              'state': 'active',
              'connectedAt': DateTime.now().millisecondsSinceEpoch,
              'recordingSince': since,
            },
          ],
        }),
      );
      await tester.pump();
    }

    testWidgets('More > Record call only when it is turned on', (
      WidgetTester tester,
    ) async {
      await pump(tester, enabled: false);
      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('tool-record')), findsNothing);
      await calls.close();
    });

    testWidgets('More > Record call starts recording', (
      WidgetTester tester,
    ) async {
      await pump(tester, enabled: true);
      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      final Rect record = tester.getRect(
        find.byKey(const ValueKey<String>('tool-record')),
      );
      expect(
        record.bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey<String>('tool-note'))).top,
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('tool-record')));
      await tester.pumpAndSettle();
      expect(tools.done, <String>['record c1 true']);
      await calls.close();
    });

    testWidgets('a recording call shows it under the status', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        enabled: true,
        since: DateTime.now().millisecondsSinceEpoch,
      );
      final Finder row = find.byKey(const ValueKey<String>('call-recording'));
      expect(find.text('Recording 00:00'), findsOneWidget);
      expect(
        tester.getRect(row).top,
        greaterThanOrEqualTo(tester.getRect(find.text('00:00')).bottom),
      );
      expect(
        tester.getRect(row).bottom,
        lessThan(tester.getRect(find.bySemanticsLabel('Mute')).top),
      );
      await calls.close();
    });
  });
}
