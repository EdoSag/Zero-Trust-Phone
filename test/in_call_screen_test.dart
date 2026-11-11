import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/app/phone_config.dart';
import 'package:zerotrust_phone/call/call_state.dart';
import 'package:zerotrust_phone/call/in_call_app.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

class FakeCallControl extends CallControl {
  final List<String> done = <String>[];
  final StreamController<(String, String)> rtt =
      StreamController<(String, String)>.broadcast();
  bool cameraAllowed = true;

  @override
  Stream<(String, String)> get rttText => rtt.stream;
  @override
  Future<void> answerVideo(String id) async => done.add('answerVideo $id');
  @override
  Future<bool> requestCamera() async {
    done.add('camera');
    return cameraAllowed;
  }

  @override
  Future<void> rttRequest(String id) async => done.add('rttRequest $id');
  @override
  Future<void> rttRespond(String id, bool accept) async =>
      done.add('rttRespond $id $accept');
  @override
  Future<void> rttWrite(String id, String text) async => done.add(
    'rtt $id ${text.replaceAll('\b', '<bs>').replaceAll('\n', '<nl>')}',
  );
  @override
  Future<void> videoRequest(String id) async => done.add('videoRequest $id');
  @override
  Future<void> videoStop(String id) async => done.add('videoStop $id');
  @override
  Future<void> videoCamera(String id, bool on) async =>
      done.add('videoCamera $id $on');
  @override
  Future<void> videoSwitchCamera(String id) async => done.add('flip $id');
  @override
  Future<void> videoRespond(String id, bool accept) async =>
      done.add('videoRespond $id $accept');

  @override
  Future<void> answer(String id) async => done.add('answer $id');
  @override
  Future<void> reject(String id) async => done.add('reject $id');
  @override
  Future<void> hangUp(String id) async => done.add('hangUp $id');
  @override
  Future<void> mute(bool on) async => done.add('mute $on');
  @override
  Future<void> route(int route) async => done.add('route $route');
  @override
  Future<void> close() async => done.add('close');
  @override
  Future<void> selectAccount(String id, int index) async =>
      done.add('sim $id $index');
  @override
  Future<void> rejectWithMessage(String id, String message) async =>
      done.add('text $id $message');
  @override
  Future<void> endAndAnswer(String id) async => done.add('endAnswer $id');
}

void main() {
  late StreamController<CallsSnapshot> calls;
  late FakeCallControl control;

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = ZtLanguages.english,
  }) async {
    calls = StreamController<CallsSnapshot>();
    control = FakeCallControl();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ztAppConfigProvider.overrideWithValue(phoneAppConfig),
          ztPreferencesStoreProvider.overrideWithValue(
            InMemoryPreferencesStore(),
          ),
          callControlProvider.overrideWithValue(control),
          callsProvider.overrideWith((ref) => calls.stream),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: ZtLanguages.supported,
          localizationsDelegates: const [
            AppL10n.delegate,
            ...ZtLanguages.delegates,
          ],
          home: const InCallScreen(),
        ),
      ),
    );
    await tester.pump(); // Loads the strings.
  }

  testWidgets('incoming call: answer and decline', (tester) async {
    await pump(tester);
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          <Object?, Object?>{
            'id': 'c1',
            'number': '+447700900123',
            'name': 'Ada Lovelace',
            'state': 'ringing',
          },
        ],
      }),
    );
    await tester.pump();
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Incoming call'), findsOneWidget);
    await tester.tap(find.byTooltip('Answer'));
    expect(control.done, <String>['answer c1']);
    await tester.tap(find.byTooltip('Decline'));
    expect(control.done.last, 'reject c1');
  });

  testWidgets('active call: mute, speaker, end; closes when it ends', (
    tester,
  ) async {
    await pump(tester);
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          <Object?, Object?>{
            'id': 'c1',
            'number': '07700900123',
            'state': 'active',
            'connectedAt': DateTime.now().millisecondsSinceEpoch,
            'canHold': true,
          },
        ],
        'audio': <Object?, Object?>{
          'muted': false,
          'route': AudioRoute.earpiece,
          'supportedRoutes': AudioRoute.earpiece | AudioRoute.speaker,
        },
      }),
    );
    await tester.pump();
    expect(find.text(ltr('07700900123')), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Mute'));
    await tester.tap(find.bySemanticsLabel('Speaker'));
    await tester.tap(find.byTooltip('End call'));
    expect(control.done, <String>[
      'mute true',
      'route ${AudioRoute.speaker}',
      'hangUp c1',
    ]);

    calls.add(const CallsSnapshot());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(control.done.last, 'close');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dual SIM without a default: pick the SIM', (tester) async {
    await pump(tester);
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          <Object?, Object?>{
            'id': 'c1',
            'number': '07700900123',
            'state': 'selectAccount',
            'accounts': <Object?>['Work', 'Personal'],
          },
        ],
      }),
    );
    await tester.pump();
    expect(find.text('Choose a SIM'), findsOneWidget);
    await tester.tap(find.text('Call with Personal'));
    expect(control.done, <String>['sim c1 1']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('decline with a quick reply', (tester) async {
    await pump(tester);
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          <Object?, Object?>{
            'id': 'c1',
            'number': '+447700900123',
            'state': 'ringing',
          },
        ],
      }),
    );
    await tester.pump();
    await tester.tap(find.text('Reply with a message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('On my way.'));
    await tester.pumpAndSettle();
    expect(control.done, <String>['text c1 On my way.']);
  });

  testWidgets('call waiting: hold & answer, or end & answer', (tester) async {
    await pump(tester);
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          <Object?, Object?>{'id': 'c1', 'number': '111', 'state': 'active'},
          <Object?, Object?>{'id': 'c2', 'number': '222', 'state': 'ringing'},
        ],
      }),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Hold & answer'));
    await tester.tap(find.byTooltip('End & answer'));
    expect(control.done, <String>['answer c2', 'endAnswer c2']);
  });

  testWidgets('car mode shows big mute and audio buttons', (tester) async {
    await pump(tester);
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'carMode': true,
        'calls': <Object?>[
          <Object?, Object?>{'id': 'c1', 'number': '111', 'state': 'active'},
        ],
        'audio': <Object?, Object?>{
          'muted': false,
          'route': 2,
          'supportedRoutes': 1 | 2 | 8,
        },
      }),
    );
    await tester.pump();
    expect(find.text('Keypad'), findsNothing);
    await tester.tap(find.text('Mute'));
    await tester.tap(find.text('Car audio'));
    await tester.tap(find.byTooltip('End call'));
    expect(control.done, <String>['mute true', 'route 8', 'hangUp c1']);
  });

  testWidgets('Hebrew: the incoming call screen is translated and RTL, the '
      'number stays left-to-right', (tester) async {
    await pump(tester, locale: ZtLanguages.hebrew);
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          <Object?, Object?>{
            'id': 'c1',
            'number': '+447700900123',
            'name': 'עדה',
            'state': 'ringing',
          },
        ],
      }),
    );
    await tester.pump();
    expect(find.text('שיחה נכנסת'), findsOneWidget);
    expect(find.text(ltr('+447700900123')), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(InCallScreen))),
      TextDirection.rtl,
    );
    // Decline comes first in the row, so in Hebrew it is on the right.
    final Rect decline = tester.getRect(find.byTooltip('דחייה'));
    final Rect answer = tester.getRect(find.byTooltip('מענה'));
    expect(decline.left, greaterThan(answer.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('P12: RTT and video buttons only when the carrier offers them', (
    tester,
  ) async {
    // A small phone: every button still fits above End call.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pump(tester);
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          <Object?, Object?>{'id': 'c1', 'number': '111', 'state': 'active'},
        ],
      }),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('RTT'), findsNothing);
    expect(find.bySemanticsLabel('Video'), findsNothing);

    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          <Object?, Object?>{
            'id': 'c1',
            'number': '111',
            'state': 'active',
            'canRtt': true,
            'canVideo': true,
            'canHold': true,
          },
        ],
      }),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'no overflow');
    final Rect end = tester.getRect(find.byTooltip('End call'));
    for (final String label in <String>['Mute', 'Hold', 'Video', 'RTT']) {
      expect(
        tester.getRect(find.bySemanticsLabel(label)).bottom,
        lessThan(end.top),
        reason: label,
      );
    }
    await tester.tap(find.bySemanticsLabel('RTT'));
    await tester.tap(find.bySemanticsLabel('Video'));
    await tester.pump();
    expect(control.done, <String>[
      'rttRequest c1',
      'camera',
      'videoRequest c1',
    ]);
  });

  testWidgets('P12: an RTT call becomes a live chat', (tester) async {
    await pump(tester);
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          <Object?, Object?>{
            'id': 'c1',
            'number': '111',
            'name': 'Ada',
            'state': 'active',
            'rttActive': true,
            'connectedAt': DateTime.now().millisecondsSinceEpoch,
          },
        ],
      }),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('rtt-input')), findsOneWidget);
    expect(find.text('Keypad'), findsNothing);

    // Their words show up while they type.
    control.rtt.add(('c1', 'Hel'));
    await tester.pump();
    expect(find.text('Hel …'), findsOneWidget);
    control.rtt.add(('c1', 'lo\n'));
    await tester.pump();
    expect(find.text('Hello'), findsOneWidget);

    // Ours go out letter by letter, and erasing is sent too.
    final Finder input = find.byKey(const ValueKey<String>('rtt-input'));
    await tester.enterText(input, 'Hi');
    await tester.enterText(input, 'Hey');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(control.done, <String>['rtt c1 Hi', 'rtt c1 <bs>ey', 'rtt c1 <nl>']);
    expect(find.text('Hey'), findsOneWidget);

    // Theirs sit on the start side, ours on the end side.
    final Rect theirs = tester.getRect(find.text('Hello'));
    final Rect ours = tester.getRect(find.text('Hey'));
    expect(ours.right, greaterThan(theirs.right));
    expect(theirs.bottom, lessThan(ours.top));

    // The input sits above the end-call button, with nothing overlapping.
    final Rect field = tester.getRect(input);
    final Rect end = tester.getRect(find.byTooltip('End call'));
    expect(field.bottom, lessThanOrEqualTo(end.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('P12: they ask to switch to RTT', (tester) async {
    await pump(tester);
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          <Object?, Object?>{
            'id': 'c1',
            'number': '111',
            'state': 'active',
            'rttRequest': true,
          },
        ],
      }),
    );
    await tester.pump();
    expect(
      find.text('They want to switch to real-time text (RTT).'),
      findsOneWidget,
    );
    await tester.tap(find.text('Accept'));
    expect(control.done, <String>['rttRespond c1 true']);
  });

  testWidgets('P12: incoming video call: answer with video or voice', (
    tester,
  ) async {
    await pump(tester);
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          <Object?, Object?>{
            'id': 'c1',
            'number': '111',
            'state': 'ringing',
            'videoState': VideoState.bidirectional,
          },
        ],
      }),
    );
    await tester.pump();
    expect(find.text('Incoming video call'), findsOneWidget);
    await tester.tap(find.byTooltip('Voice'));
    await tester.tap(find.byTooltip('Video'));
    await tester.pump();
    expect(control.done, <String>['answer c1', 'camera', 'answerVideo c1']);
    // Three buttons in one row, none overlapping.
    final Rect decline = tester.getRect(find.byTooltip('Decline'));
    final Rect voice = tester.getRect(find.byTooltip('Voice'));
    final Rect video = tester.getRect(find.byTooltip('Video'));
    expect(decline.right, lessThan(voice.left));
    expect(voice.right, lessThan(video.left));
  });

  testWidgets('P12: a video call shows both videos and its controls', (
    tester,
  ) async {
    await pump(tester);
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          <Object?, Object?>{
            'id': 'c1',
            'number': '111',
            'name': 'Ada',
            'state': 'active',
            'videoState': VideoState.bidirectional,
            'displayTexture': 7,
            'previewTexture': 8,
            'peerWidth': 480,
            'peerHeight': 640,
            'previewWidth': 640,
            'previewHeight': 480,
          },
        ],
      }),
    );
    await tester.pump();
    final Finder remote = find.byKey(const ValueKey<String>('remote-video'));
    final Finder own = find.byKey(const ValueKey<String>('own-video'));
    expect(remote, findsOneWidget);
    expect(own, findsOneWidget);
    // Our camera is a small upright picture in the top corner.
    final Size ownSize = tester.getSize(own);
    expect(ownSize.width, 110);
    expect(ownSize.height, closeTo(110 * 640 / 480, 0.5));
    expect(
      tester.getRect(own).bottom,
      lessThan(tester.getRect(find.bySemanticsLabel('Mute')).top),
    );

    await tester.tap(find.bySemanticsLabel('Camera off'));
    await tester.tap(find.bySemanticsLabel('Flip'));
    await tester.tap(find.bySemanticsLabel('Voice only'));
    await tester.tap(find.byTooltip('End call'));
    expect(control.done, <String>[
      'videoCamera c1 false',
      'flip c1',
      'videoStop c1',
      'hangUp c1',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('P12: a camera the carrier kept "on" can be turned back on, '
      'and a request to turn it on shows over their video', (tester) async {
    await pump(tester);
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          <Object?, Object?>{
            'id': 'c1',
            'number': '111',
            'name': 'Ada',
            'state': 'active',
            // The carrier refused to stop sending; the camera is off anyway.
            'videoState': VideoState.bidirectional,
            'cameraOff': true,
            'videoRequest': true,
            'displayTexture': 7,
            'peerWidth': 480,
            'peerHeight': 640,
          },
        ],
      }),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('remote-video')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('own-video')), findsNothing);
    expect(find.bySemanticsLabel('Camera off'), findsNothing);
    expect(find.bySemanticsLabel('Flip'), findsNothing);
    // The request sits above the caller's name, inside the screen.
    final Rect banner = tester.getRect(
      find.text('They want to switch to video.'),
    );
    expect(banner.bottom, lessThan(tester.getRect(find.text('Ada')).top));
    expect(banner.left, greaterThan(0));

    await tester.tap(find.bySemanticsLabel('Camera on'));
    await tester.pump();
    await tester.tap(find.text('Decline'));
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(control.done, <String>[
      'camera',
      'videoCamera c1 true',
      'videoRespond c1 false',
      'camera',
      'videoRespond c1 true',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('P12 in Hebrew: the RTT chat is translated and mirrored', (
    tester,
  ) async {
    await pump(tester, locale: ZtLanguages.hebrew);
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          <Object?, Object?>{
            'id': 'c1',
            'number': '111',
            'state': 'active',
            'rttActive': true,
          },
        ],
      }),
    );
    await tester.pump();
    expect(find.text('כתיבת הודעה'), findsOneWidget);
    control.rtt.add(('c1', 'שלום\n'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('rtt-input')),
      'היי',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    // In Hebrew theirs are on the right, ours on the left.
    expect(
      tester.getRect(find.text('שלום')).right,
      greaterThan(tester.getRect(find.text('היי')).right),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('P12: an RTT line survives a call-waiting interruption', (
    tester,
  ) async {
    await pump(tester);
    Map<Object?, Object?> rttCall(String state) => <Object?, Object?>{
      'id': 'c1',
      'number': '111',
      'state': state,
      'rttActive': true,
    };
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[rttCall('active')],
      }),
    );
    await tester.pump();
    final Finder input = find.byKey(const ValueKey<String>('rtt-input'));
    await tester.enterText(input, 'Half a sen');

    // A second call rings: the RTT panel goes away for the incoming screen.
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[
          rttCall('active'),
          <Object?, Object?>{'id': 'c2', 'number': '222', 'state': 'ringing'},
        ],
      }),
    );
    await tester.pump();
    await tester.pump();
    expect(input, findsNothing);

    // Back to the RTT call: the field shows what they already see.
    calls.add(
      CallsSnapshot.fromMap(<Object?, Object?>{
        'calls': <Object?>[rttCall('active')],
      }),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Half a sen'), findsOneWidget);
    await tester.enterText(input, 'Half a sentence');
    expect(control.done.last, 'rtt c1 tence');
  });
}
