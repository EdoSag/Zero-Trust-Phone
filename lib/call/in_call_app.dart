import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/call/call_state.dart';
import 'package:zerotrust_phone/pages/dialpad_page.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';

/// Talks to CallManager.kt. Overridable in tests.
class CallControl {
  CallControl({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('zt_phone/call_control'),
      _events = events ?? const EventChannel('zt_phone/call_state');

  final MethodChannel _methods;
  final EventChannel _events;

  Stream<CallsSnapshot> get states => _events.receiveBroadcastStream().map(
    (Object? e) => CallsSnapshot.fromMap(e! as Map<Object?, Object?>),
  );

  Future<void> _do(String method, [Map<String, Object?>? args]) =>
      _methods.invokeMethod<void>(method, args);

  Future<void> answer(String id) => _do('answer', {'id': id});
  Future<void> reject(String id) => _do('reject', {'id': id});
  Future<void> hangUp(String id) => _do('hangUp', {'id': id});
  Future<void> hold(String id, bool on) => _do('hold', {'id': id, 'on': on});
  Future<void> swap() => _do('swap');
  Future<void> merge() => _do('merge');
  Future<void> dtmf(String digit) => _do('dtmf', {'digit': digit});
  Future<void> mute(bool on) => _do('mute', {'on': on});
  Future<void> route(int route) => _do('route', {'route': route});
  Future<void> addCall() => _do('addCall');
  Future<void> selectAccount(String id, int index) =>
      _do('selectAccount', {'id': id, 'index': index});
  Future<void> close() => _do('close');
}

final callControlProvider = Provider<CallControl>((ref) => CallControl());

final callsProvider = StreamProvider<CallsSnapshot>(
  (ref) => ref.watch(callControlProvider).states,
);

class InCallApp extends ConsumerWidget {
  const InCallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ZtThemeBuilder(
    builder: (context, theme, darkTheme, mode) => MaterialApp(
      title: 'ZT Phone',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: mode,
      home: const InCallScreen(),
    ),
  );
}

class InCallScreen extends ConsumerStatefulWidget {
  const InCallScreen({super.key});

  @override
  ConsumerState<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends ConsumerState<InCallScreen> {
  bool _keypad = false;
  String _typed = '';
  Timer? _ticker;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _closeTimer?.cancel();
    super.dispose();
  }

  CallControl get _control => ref.read(callControlProvider);

  @override
  Widget build(BuildContext context) {
    ref.listen(callsProvider, (_, AsyncValue<CallsSnapshot> next) {
      final CallsSnapshot? s = next.value;
      if (s == null) return;
      final bool ended =
          s.calls.isEmpty ||
          s.calls.every((PhoneCall c) => c.state == CallState.disconnected);
      if (ended) {
        // Leave "Call ended" up for a moment, like other dialers.
        _closeTimer ??= Timer(const Duration(milliseconds: 1200), () {
          _closeTimer = null;
          _keypad = false;
          _typed = '';
          _control.close();
        });
      } else {
        _closeTimer?.cancel();
        _closeTimer = null;
      }
    });

    final CallsSnapshot snapshot =
        ref.watch(callsProvider).value ?? const CallsSnapshot();
    final PhoneCall? call = snapshot.primary;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        child: call == null
            ? const Center(child: Text('Call ended'))
            : Column(
                children: <Widget>[
                  if (snapshot.secondary case final PhoneCall other)
                    _OtherCallBar(call: other, onSwap: _control.swap),
                  const SizedBox(height: 32),
                  _CallerHeader(call: call),
                  const Spacer(),
                  if (call.state == CallState.selectAccount)
                    _PickSim(
                      call: call,
                      onPick: (int i) => _control.selectAccount(call.id, i),
                      onCancel: () => _control.hangUp(call.id),
                    )
                  else if (call.state == CallState.ringing)
                    _IncomingActions(
                      onAnswer: () => _control.answer(call.id),
                      onDecline: () => _control.reject(call.id),
                    )
                  else ...<Widget>[
                    if (_keypad) ...<Widget>[
                      Text(
                        _typed,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      DialKeypad(
                        onKey: (String d) {
                          HapticFeedback.selectionClick();
                          setState(() => _typed += d);
                          _control.dtmf(d);
                        },
                      ),
                    ] else
                      _Controls(
                        snapshot: snapshot,
                        call: call,
                        control: _control,
                        onKeypad: () => setState(() => _keypad = true),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (_keypad)
                          SizedBox(
                            width: 96,
                            child: TextButton(
                              onPressed: () => setState(() => _keypad = false),
                              child: const Text('Hide'),
                            ),
                          ),
                        _RoundButton(
                          color: Colors.red.shade600,
                          icon: Icons.call_end,
                          label: 'End call',
                          onPressed: () => _control.hangUp(call.id),
                        ),
                        if (_keypad) const SizedBox(width: 96),
                      ],
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }
}

class _CallerHeader extends StatelessWidget {
  const _CallerHeader({required this.call});
  final PhoneCall call;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String status = switch (call.state) {
      CallState.ringing => 'Incoming call',
      CallState.selectAccount => 'Choose a SIM',
      CallState.dialing || CallState.connecting => 'Calling…',
      CallState.holding => 'On hold',
      CallState.disconnecting || CallState.disconnected => 'Call ended',
      CallState.active => _elapsed(call.connectedAt),
      CallState.other => '',
    };
    return Column(
      children: <Widget>[
        ContactAvatar(label: call.name ?? '', radius: 48),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            call.title,
            style: text.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
        if (call.name != null && call.number.isNotEmpty)
          Text(call.number, style: text.titleMedium),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: call.state != CallState.active,
          child: Text(status, style: text.titleMedium),
        ),
      ],
    );
  }

  static String _elapsed(DateTime? since) {
    if (since == null) return 'Connected';
    final Duration d = DateTime.now().difference(since);
    String two(int n) => n.toString().padLeft(2, '0');
    final int h = d.inHours;
    final String ms = '${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    return h > 0 ? '$h:$ms' : ms;
  }
}

/// Dual-SIM phones without a default SIM for calls ask which one to use.
class _PickSim extends StatelessWidget {
  const _PickSim({
    required this.call,
    required this.onPick,
    required this.onCancel,
  });

  final PhoneCall call;
  final ValueChanged<int> onPick;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < call.accounts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.sim_card_outlined),
              label: Text('Call with ${call.accounts[i]}'),
              onPressed: () => onPick(i),
            ),
          ),
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ],
    ),
  );
}

class _IncomingActions extends StatelessWidget {
  const _IncomingActions({required this.onAnswer, required this.onDecline});
  final VoidCallback onAnswer;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: <Widget>[
      _RoundButton(
        color: Colors.red.shade600,
        icon: Icons.call_end,
        label: 'Decline',
        onPressed: onDecline,
      ),
      _RoundButton(
        color: Colors.green.shade600,
        icon: Icons.call,
        label: 'Answer',
        onPressed: onAnswer,
      ),
    ],
  );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.snapshot,
    required this.call,
    required this.control,
    required this.onKeypad,
  });

  final CallsSnapshot snapshot;
  final PhoneCall call;
  final CallControl control;
  final VoidCallback onKeypad;

  @override
  Widget build(BuildContext context) {
    final bool speaker = snapshot.route == AudioRoute.speaker;
    final bool held = call.state == CallState.holding;
    final bool twoCalls = snapshot.secondary != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 16,
        children: <Widget>[
          _Toggle(
            icon: snapshot.muted ? Icons.mic_off : Icons.mic_none,
            label: 'Mute',
            on: snapshot.muted,
            onTap: () => control.mute(!snapshot.muted),
          ),
          _Toggle(icon: Icons.dialpad, label: 'Keypad', onTap: onKeypad),
          _Toggle(
            icon: snapshot.hasBluetooth
                ? (snapshot.route == AudioRoute.bluetooth
                      ? Icons.bluetooth_audio
                      : (speaker ? Icons.volume_up : Icons.phone_in_talk))
                : Icons.volume_up,
            label: snapshot.hasBluetooth ? 'Audio' : 'Speaker',
            on: snapshot.hasBluetooth
                ? snapshot.route != AudioRoute.earpiece
                : speaker,
            onTap: () => snapshot.hasBluetooth
                ? _pickRoute(context)
                : control.route(
                    speaker ? AudioRoute.earpiece : AudioRoute.speaker,
                  ),
          ),
          if (call.canHold || held)
            _Toggle(
              icon: held ? Icons.play_arrow : Icons.pause,
              label: held ? 'Resume' : 'Hold',
              on: held,
              onTap: () => control.hold(call.id, !held),
            ),
          if (twoCalls && call.canMerge)
            _Toggle(
              icon: Icons.call_merge,
              label: 'Merge',
              onTap: control.merge,
            ),
          if (!twoCalls)
            _Toggle(
              icon: Icons.add_call,
              label: 'Add call',
              onTap: control.addCall,
            ),
        ],
      ),
    );
  }

  Future<void> _pickRoute(BuildContext context) async {
    final List<(int, IconData, String)> routes = <(int, IconData, String)>[
      if (snapshot.supportedRoutes & AudioRoute.bluetooth != 0)
        (AudioRoute.bluetooth, Icons.bluetooth_audio, 'Bluetooth'),
      if (snapshot.supportedRoutes & AudioRoute.wiredHeadset != 0)
        (AudioRoute.wiredHeadset, Icons.headset, 'Headset')
      else if (snapshot.supportedRoutes & AudioRoute.earpiece != 0)
        (AudioRoute.earpiece, Icons.phone_in_talk, 'Phone'),
      (AudioRoute.speaker, Icons.volume_up, 'Speaker'),
    ];
    final int? picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (int route, IconData icon, String label) in routes)
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                trailing: snapshot.route == route
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(sheet).pop(route),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await control.route(picked);
  }
}

class _OtherCallBar extends StatelessWidget {
  const _OtherCallBar({required this.call, required this.onSwap});
  final PhoneCall call;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: ListTile(
      leading: const Icon(Icons.pause_circle_outline),
      title: Text(call.title),
      subtitle: Text(call.state == CallState.holding ? 'On hold' : 'Calling…'),
      trailing: TextButton(onPressed: onSwap, child: const Text('Swap')),
    ),
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.onTap,
    this.on = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 88,
      child: Semantics(
        button: true,
        toggled: on,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: <Widget>[
                CircleAvatar(
                  radius: 28,
                  backgroundColor: on
                      ? scheme.primary
                      : scheme.surfaceContainerHigh,
                  foregroundColor: on ? scheme.onPrimary : scheme.onSurface,
                  child: Icon(icon),
                ),
                const SizedBox(height: 6),
                Text(label, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SizedBox(
        width: 72,
        height: 72,
        child: FloatingActionButton(
          heroTag: label,
          shape: const CircleBorder(),
          backgroundColor: color,
          foregroundColor: Colors.white,
          tooltip: label,
          onPressed: onPressed,
          child: Icon(icon, size: 32),
        ),
      ),
      const SizedBox(height: 8),
      Text(label),
    ],
  );
}
