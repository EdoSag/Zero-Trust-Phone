import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/app/phone_config.dart';
import 'package:zerotrust_phone/call/call_state.dart';
import 'package:zerotrust_phone/call/in_call_app.dart';

class FakeCallControl extends CallControl {
  final List<String> done = <String>[];

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

  Future<void> pump(WidgetTester tester) async {
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
        child: const MaterialApp(home: InCallScreen()),
      ),
    );
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
    expect(find.text('07700900123'), findsOneWidget);
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
}
