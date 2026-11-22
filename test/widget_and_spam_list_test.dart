import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/app/phone_config.dart';
import 'package:zerotrust_phone/app/recents_widget.dart';
import 'package:zerotrust_phone/call/call_state.dart';
import 'package:zerotrust_phone/call/in_call_app.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/call_protection_page.dart';
import 'package:zerotrust_phone/services/spam_list.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

/// W11 recent calls widget (what it may keep) and P24 signed spam list.
class FakeTelecom extends Telecom {
  final List<String> installed = <String>[];
  final List<String> modes = <String>[];
  bool installWorks = true;

  @override
  Future<bool> installSpamList(String text) async {
    if (!installWorks) return false;
    installed.add(text);
    return true;
  }

  @override
  Future<void> setSpamMode(String mode) async => modes.add(mode);

  @override
  Future<({String? date, int count})> spamListInfo() async => installed.isEmpty
      ? (date: null, count: 0)
      : (date: SpamListUpdater.listDateOf(installed.last), count: 2);
}

class FakeCallControl extends CallControl {
  @override
  Stream<(String, String)> get rttText =>
      const Stream<(String, String)>.empty();
}

String list(String date) =>
    '$spamListHeader\n# list-date: $date\n+12025550123\t7\n+972501234567\t1\n';

class SignedFiles {
  SignedFiles(this.pair, this.publicKey);
  final SimpleKeyPair pair;
  final String publicKey;
  final Map<String, List<int>> files = <String, List<int>>{};
  int fetches = 0;

  static Future<SignedFiles> make() async {
    final SimpleKeyPair pair = await Ed25519().newKeyPair();
    final SimplePublicKey pub = await pair.extractPublicKey();
    return SignedFiles(pair, base64.encode(pub.bytes));
  }

  Future<void> publish(String text) async {
    final List<int> gz = gzip.encode(utf8.encode(text));
    final Signature sig = await Ed25519().sign(gz, keyPair: pair);
    files['spam-list.txt.gz'] = gz;
    files['spam-list.txt.gz.sig'] = utf8.encode(base64.encode(sig.bytes));
  }

  Future<List<int>?> fetch(Uri url, int maxBytes) async {
    fetches++;
    return files[url.pathSegments.last];
  }
}

void main() {
  group('recent calls widget (W11)', () {
    test('keeps contact names but never a private contact', () {
      expect(
        widgetNames(
          <String, String>{
            '541234567': 'Dana Levi',
            '507654321': 'Secret friend',
            '521111111': '  ',
          },
          <String>['507654321'],
        ),
        <String, String>{'541234567': 'Dana Levi'},
      );
    });

    test('"Show details on the home screen" is off until turned on', () async {
      final InMemoryPreferencesStore prefs = InMemoryPreferencesStore();
      final ProviderContainer c = ProviderContainer(
        overrides: [ztPreferencesStoreProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      await c.read(recentsWidgetDetailsProvider.notifier).loaded;
      expect(c.read(recentsWidgetDetailsProvider), isFalse);
      await c.read(recentsWidgetDetailsProvider.notifier).set(true);
      expect(prefs.values[RecentsWidgetDetails.key], 'on');

      final ProviderContainer again = ProviderContainer(
        overrides: [ztPreferencesStoreProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      await again.read(recentsWidgetDetailsProvider.notifier).loaded;
      expect(again.read(recentsWidgetDetailsProvider), isTrue);
    });
  });

  group('spam list (P24)', () {
    late SignedFiles server;
    late FakeTelecom telecom;
    late InMemoryPreferencesStore prefs;
    late SpamListUpdater updater;

    setUp(() async {
      server = await SignedFiles.make();
      telecom = FakeTelecom();
      prefs = InMemoryPreferencesStore();
      updater = SpamListUpdater(
        telecom,
        prefs,
        fetch: server.fetch,
        publicKey: server.publicKey,
      );
    });

    test(
      'a signed list is installed, then not again until it changes',
      () async {
        await server.publish(list('2026-11-17T04:23'));
        expect(await updater.checkIfDue(SpamMode.warn), SpamListCheck.updated);
        expect(telecom.installed.single, list('2026-11-17T04:23'));
        expect(await updater.listDate(), '2026-11-17T04:23');

        expect(await updater.checkIfDue(SpamMode.warn), SpamListCheck.notDue);
        expect(
          await updater.checkIfDue(SpamMode.warn, force: true),
          SpamListCheck.upToDate,
        );
        await server.publish(list('2026-11-24T04:23'));
        expect(
          await updater.checkIfDue(SpamMode.warn, force: true),
          SpamListCheck.updated,
        );
        expect(telecom.installed, hasLength(2));
      },
    );

    test('a changed file is refused', () async {
      await server.publish(list('2026-11-17T04:23'));
      final List<int> gz = gzip.encode(
        utf8.encode('${list('2026-11-17T04:23')}+15555550100\t9\n'),
      );
      server.files['spam-list.txt.gz'] = gz;
      expect(await updater.checkIfDue(SpamMode.warn), SpamListCheck.failed);
      expect(telecom.installed, isEmpty);
      // A failed check is tried again next time, not a week later.
      expect(await updater.lastCheck(), isNull);
    });

    test('a list signed with another key is refused', () async {
      final SignedFiles other = await SignedFiles.make();
      await other.publish(list('2026-11-17T04:23'));
      server.files.addAll(other.files);
      expect(await updater.checkIfDue(SpamMode.warn), SpamListCheck.failed);
      expect(telecom.installed, isEmpty);
    });

    test('a signed file that is not a ZT Phone spam list is refused', () async {
      await server.publish(
        '# ZT Browser blocklist, format 1.\n# list-date: 2026-11-17T04:23\n',
      );
      expect(await updater.checkIfDue(SpamMode.warn), SpamListCheck.failed);
      expect(telecom.installed, isEmpty);
    });

    test('nothing is downloaded while it is off', () async {
      await server.publish(list('2026-11-17T04:23'));
      expect(
        await updater.checkIfDue(SpamMode.off, force: true),
        SpamListCheck.off,
      );
      expect(server.fetches, 0);
    });

    testWidgets('settings: pick what happens and check for a list', (
      WidgetTester tester,
    ) async {
      await server.publish(list('2026-11-17T04:23'));
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            ztPreferencesStoreProvider.overrideWithValue(prefs),
            telecomProvider.overrideWithValue(telecom),
            spamListUpdaterProvider.overrideWithValue(updater),
          ],
          child: MaterialApp(
            supportedLocales: ZtLanguages.supported,
            localizationsDelegates: const <LocalizationsDelegate<Object>>[
              AppL10n.delegate,
              ...ZtLanguages.delegates,
            ],
            home: const Scaffold(
              body: SingleChildScrollView(child: SpamListSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No list downloaded yet'), findsOneWidget);

      // Choices are in order, one under the other.
      final List<double> tops = <double>[
        for (final SpamMode m in SpamMode.values)
          tester.getRect(find.byKey(ValueKey<String>('spam-${m.name}'))).top,
      ];
      expect(tops, orderedEquals(List<double>.of(tops)..sort()));

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey<String>('spam-check')));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(telecom.installed, hasLength(1));
      expect(find.text('The spam list is updated'), findsOneWidget);
      expect(
        find.text('List from 2026-11-17 04:23, 2 numbers'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('spam-voicemail')));
      await tester.pumpAndSettle();
      expect(telecom.modes, <String>['voicemail']);
      expect(prefs.values[SpamModeNotifier.key], 'voicemail');

      await tester.tap(find.byKey(const ValueKey<String>('spam-off')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('spam-check')), findsNothing);
    });

    testWidgets('the call screen warns about a reported number', (
      WidgetTester tester,
    ) async {
      final StreamController<CallsSnapshot> calls =
          StreamController<CallsSnapshot>();
      await tester.binding.setSurfaceSize(const Size(400, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            ztAppConfigProvider.overrideWithValue(phoneAppConfig),
            ztPreferencesStoreProvider.overrideWithValue(prefs),
            callControlProvider.overrideWithValue(FakeCallControl()),
            callsProvider.overrideWith((ref) => calls.stream),
          ],
          child: MaterialApp(
            supportedLocales: ZtLanguages.supported,
            localizationsDelegates: const <LocalizationsDelegate<Object>>[
              AppL10n.delegate,
              ...ZtLanguages.delegates,
            ],
            home: const InCallScreen(),
          ),
        ),
      );
      await tester.pump();
      calls.add(
        CallsSnapshot.fromMap(<Object?, Object?>{
          'calls': <Object?>[
            <Object?, Object?>{
              'id': 'c1',
              'number': '+12025550123',
              'state': 'ringing',
              'spamReports': 7,
            },
          ],
        }),
      );
      await tester.pump();
      final Finder warning = find.byKey(const ValueKey<String>('call-spam'));
      expect(find.text('Reported as spam 7 times'), findsOneWidget);
      expect(
        tester.getRect(warning).top,
        greaterThanOrEqualTo(tester.getRect(find.text('Incoming call')).bottom),
      );
      await calls.close();
    });
  });
}
