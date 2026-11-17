import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/home_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

class FakeTelecom extends Telecom {
  FakeTelecom({this.hasCall = false});
  bool hasCall;
  int opened = 0;

  @override
  Future<bool> refreshCall() async {
    callInProgress.value = hasCall;
    return hasCall;
  }

  @override
  Future<bool> openCallScreen() async {
    opened++;
    if (!hasCall) callInProgress.value = false;
    return hasCall;
  }
}

void main() {
  Future<FakeTelecom> pump(
    WidgetTester tester, {
    bool hasCall = false,
    Locale locale = ZtLanguages.english,
  }) async {
    final FakeTelecom telecom = FakeTelecom(hasCall: hasCall);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [telecomProvider.overrideWithValue(telecom)],
        child: MaterialApp(
          locale: locale,
          supportedLocales: ZtLanguages.supported,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppL10n.delegate,
            ...ZtLanguages.delegates,
          ],
          home: const Scaffold(
            body: Column(
              children: <Widget>[
                ReturnToCallBar(),
                Expanded(child: Center(child: Text('recents'))),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return telecom;
  }

  testWidgets('no bar without a call', (WidgetTester tester) async {
    await pump(tester);
    expect(find.text('Return to call'), findsNothing);
  });

  testWidgets('a call in progress shows the bar on top, and tapping it '
      'opens the call screen', (WidgetTester tester) async {
    final FakeTelecom telecom = await pump(tester, hasCall: true);
    final Finder bar = find.text('Return to call');
    expect(bar, findsOneWidget);
    // Above the rest of the page, at the very top.
    expect(
      tester.getTopLeft(bar).dy,
      lessThan(tester.getTopLeft(find.text('recents')).dy),
    );
    expect(tester.getTopLeft(find.byType(ReturnToCallBar)).dy, 0);
    await tester.tap(bar);
    await tester.pumpAndSettle();
    expect(telecom.opened, 1);
  });

  testWidgets('the bar comes and goes with the call', (
    WidgetTester tester,
  ) async {
    final FakeTelecom telecom = await pump(tester);
    telecom.callInProgress.value = true;
    await tester.pump();
    expect(find.text('Return to call'), findsOneWidget);
    telecom.callInProgress.value = false;
    await tester.pump();
    expect(find.text('Return to call'), findsNothing);
  });

  testWidgets('a call that ended meanwhile hides the bar on tap', (
    WidgetTester tester,
  ) async {
    final FakeTelecom telecom = await pump(tester, hasCall: true);
    telecom.hasCall = false;
    await tester.tap(find.text('Return to call'));
    await tester.pumpAndSettle();
    expect(find.text('Return to call'), findsNothing);
  });

  testWidgets('Hebrew', (WidgetTester tester) async {
    await pump(tester, hasCall: true, locale: ZtLanguages.hebrew);
    expect(find.text('חזרה לשיחה'), findsOneWidget);
  });

  test('Android tells the app when calls start and end', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const MethodChannel channel = MethodChannel('zt_phone/telecom');
    final Telecom telecom = Telecom(channel)..listenForDials();
    Future<void> push(bool has) async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'zt_phone/telecom',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('callsChanged', has),
            ),
            (_) {},
          );
    }

    await push(true);
    expect(telecom.callInProgress.value, isTrue);
    await push(false);
    expect(telecom.callInProgress.value, isFalse);
  });
}
