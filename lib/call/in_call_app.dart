import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/call/call_state.dart';
import 'package:zerotrust_phone/call/rtt.dart';
import 'package:zerotrust_phone/pages/dialpad_page.dart';
import 'package:zerotrust_phone/services/quick_replies.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// Talks to CallManager.kt. Overridable in tests.
class CallControl {
  CallControl({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('zt_phone/call_control'),
      _events = events ?? const EventChannel('zt_phone/call_state');

  final MethodChannel _methods;
  final EventChannel _events;

  /// Text the other person types in an RTT call: (call id, text).
  Stream<(String, String)> get rttText =>
      const EventChannel('zt_phone/rtt_text').receiveBroadcastStream().map((
        Object? e,
      ) {
        final Map<Object?, Object?> m = e! as Map<Object?, Object?>;
        return (m['id']! as String, (m['text'] as String?) ?? '');
      });

  Stream<CallsSnapshot> get states => _events.receiveBroadcastStream().map(
    (Object? e) => CallsSnapshot.fromMap(e! as Map<Object?, Object?>),
  );

  Future<void> _do(String method, [Map<String, Object?>? args]) =>
      _methods.invokeMethod<void>(method, args);

  Future<void> answer(String id) => _do('answer', {'id': id});
  Future<void> reject(String id) => _do('reject', {'id': id});
  Future<void> rejectWithMessage(String id, String message) =>
      _do('rejectWithMessage', {'id': id, 'message': message});

  /// Call waiting: hangs up the current call and answers [id].
  Future<void> endAndAnswer(String id) => _do('endAndAnswer', {'id': id});
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

  // P12: real-time text and carrier video calls.
  Future<void> answerVideo(String id) => _do('answerVideo', {'id': id});
  Future<void> rttRequest(String id) => _do('rttRequest', {'id': id});
  Future<void> rttRespond(String id, bool accept) =>
      _do('rttRespond', {'id': id, 'accept': accept});
  Future<void> rttWrite(String id, String text) =>
      _do('rttWrite', {'id': id, 'text': text});
  Future<void> videoRequest(String id) => _do('videoRequest', {'id': id});
  Future<void> videoStop(String id) => _do('videoStop', {'id': id});
  Future<void> videoCamera(String id, bool on) =>
      _do('videoCamera', {'id': id, 'on': on});
  Future<void> videoSwitchCamera(String id) =>
      _do('videoSwitchCamera', {'id': id});
  Future<void> videoRespond(String id, bool accept) =>
      _do('videoRespond', {'id': id, 'accept': accept});

  /// Asks for the camera. True when ZT Phone may use it.
  Future<bool> requestCamera() async =>
      await _methods.invokeMethod<bool>('requestCamera') ?? false;
}

final callControlProvider = Provider<CallControl>((ref) => CallControl());

final callsProvider = StreamProvider<CallsSnapshot>(
  (ref) => ref.watch(callControlProvider).states,
);

/// Each call's RTT conversation, by call id. Never saved.
final rttProvider =
    NotifierProvider<RttConversations, Map<String, RttTranscript>>(
      RttConversations.new,
    );

class RttConversations extends Notifier<Map<String, RttTranscript>> {
  @override
  Map<String, RttTranscript> build() {
    final StreamSubscription<(String, String)> sub = ref
        .watch(callControlProvider)
        .rttText
        .listen((e) => _change(e.$1, (RttTranscript t) => t.receive(e.$2)));
    ref.onDispose(sub.cancel);
    return <String, RttTranscript>{};
  }

  void _change(String id, void Function(RttTranscript) edit) {
    final RttTranscript t = state[id] ?? RttTranscript();
    edit(t);
    state = <String, RttTranscript>{...state, id: t};
  }

  /// The text field for call [id] now holds [draft]; sends the change.
  void type(String id, String draft) {
    String delta = '';
    _change(id, (RttTranscript t) => delta = t.typed(draft));
    if (delta.isNotEmpty) ref.read(callControlProvider).rttWrite(id, delta);
  }

  /// Ends the line being typed in call [id].
  void submit(String id) {
    String send = '';
    _change(id, (RttTranscript t) => send = t.submit());
    if (send.isNotEmpty) ref.read(callControlProvider).rttWrite(id, send);
  }

  void clear() => state = <String, RttTranscript>{};
}

class InCallApp extends ConsumerWidget {
  const InCallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ZtThemeBuilder(
    builder: (context, theme, darkTheme, mode) => MaterialApp(
      title: 'ZT Phone',
      debugShowCheckedModeBanner: false,
      // The language picked in ZT Phone's settings.
      locale: ref.watch(ztLanguageProvider),
      supportedLocales: ZtLanguages.supported,
      localizationsDelegates: const [
        AppL10n.delegate,
        ...ZtLanguages.delegates,
      ],
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
          ref.read(rttProvider.notifier).clear();
          _control.close();
        });
      } else {
        _closeTimer?.cancel();
        _closeTimer = null;
      }
    });

    // Keeps RTT text coming in even before its panel opens.
    ref.listen(rttProvider, (_, _) {});

    final CallsSnapshot snapshot =
        ref.watch(callsProvider).value ?? const CallsSnapshot();
    final PhoneCall? call = snapshot.primary;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: call == null
          ? SafeArea(child: Center(child: Text(context.l10n.callEnded)))
          : _showsVideo(call)
          ? _VideoCallView(
              snapshot: snapshot,
              call: call,
              control: _control,
              onCamera: () => _turnOnCamera(call),
            )
          : SafeArea(
              child: Column(
                children: <Widget>[
                  if (snapshot.secondary case final PhoneCall other)
                    _OtherCallBar(call: other, onSwap: _control.swap),
                  if (call.rttRequest)
                    _RequestBanner(
                      icon: Icons.rtt,
                      text: context.l10n.rttRequestBody,
                      onAccept: () => _control.rttRespond(call.id, true),
                      onDecline: () => _control.rttRespond(call.id, false),
                    ),
                  if (call.videoRequest)
                    _RequestBanner(
                      icon: Icons.videocam_outlined,
                      text: context.l10n.videoRequestBody,
                      onAccept: () => _acceptVideo(call),
                      onDecline: () => _control.videoRespond(call.id, false),
                    ),
                  if (_showsRtt(call)) ...<Widget>[
                    _CompactHeader(
                      call: call,
                      snapshot: snapshot,
                      control: _control,
                    ),
                    _Notice(call: call),
                    Expanded(child: _RttPanel(call: call)),
                  ] else ...<Widget>[
                    SizedBox(height: snapshot.carMode ? 16 : 32),
                    _CallerHeader(call: call, large: snapshot.carMode),
                    _Notice(call: call),
                    const Spacer(),
                  ],
                  if (call.state == CallState.selectAccount)
                    _PickSim(
                      call: call,
                      onPick: (int i) => _control.selectAccount(call.id, i),
                      onCancel: () => _control.hangUp(call.id),
                    )
                  else if (call.state == CallState.ringing)
                    _IncomingActions(
                      // Call waiting: Telecom holds the current call when
                      // the new one is answered.
                      waiting: snapshot.secondary != null,
                      onAnswer: () => _control.answer(call.id),
                      onAnswerVideo: call.isVideo
                          ? () => _answerVideo(call)
                          : null,
                      onDecline: () => _control.reject(call.id),
                      onEndAndAnswer: () => _control.endAndAnswer(call.id),
                      onMessage: call.number.isEmpty
                          ? null
                          : () => _declineWithText(call),
                    )
                  else ...<Widget>[
                    if (_showsRtt(call))
                      const SizedBox.shrink()
                    else if (_keypad) ...<Widget>[
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
                    ] else if (snapshot.carMode)
                      _CarControls(
                        snapshot: snapshot,
                        call: call,
                        control: _control,
                      )
                    else
                      _Controls(
                        snapshot: snapshot,
                        call: call,
                        control: _control,
                        onKeypad: () => setState(() => _keypad = true),
                        onVideo: () => _startVideo(call),
                      ),
                    SizedBox(height: _showsRtt(call) ? 8 : 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (_keypad && !_showsRtt(call))
                          SizedBox(
                            width: 96,
                            child: TextButton(
                              onPressed: () => setState(() => _keypad = false),
                              child: Text(context.l10n.hide),
                            ),
                          ),
                        _RoundButton(
                          color: Colors.red.shade600,
                          icon: Icons.call_end,
                          label: context.l10n.endCall,
                          small: _showsRtt(call),
                          onPressed: () => _control.hangUp(call.id),
                        ),
                        if (_keypad && !_showsRtt(call))
                          const SizedBox(width: 96),
                      ],
                    ),
                  ],
                  SizedBox(height: _showsRtt(call) ? 12 : 40),
                ],
              ),
            ),
    );
  }
}

extension on _InCallScreenState {
  static const Set<CallState> _live = <CallState>{
    CallState.dialing,
    CallState.connecting,
    CallState.active,
  };

  /// A carrier video call with something to show (P12).
  bool _showsVideo(PhoneCall call) =>
      call.isVideo &&
      _live.contains(call.state) &&
      (call.displayTexture != null || call.previewTexture != null);

  /// Real-time text is on: the screen becomes a live chat (P12).
  bool _showsRtt(PhoneCall call) =>
      call.rttActive &&
      (_live.contains(call.state) || call.state == CallState.holding);

  /// Video needs the camera; without it the other person's video still
  /// shows, and ours stays off.
  Future<void> _startVideo(PhoneCall call) async {
    await _control.requestCamera();
    await _control.videoRequest(call.id);
  }

  Future<void> _answerVideo(PhoneCall call) async {
    await _control.requestCamera();
    await _control.answerVideo(call.id);
  }

  Future<void> _acceptVideo(PhoneCall call) async {
    await _control.requestCamera();
    await _control.videoRespond(call.id, true);
  }

  Future<void> _turnOnCamera(PhoneCall call) async {
    if (await _control.requestCamera()) {
      await _control.videoCamera(call.id, true);
    }
  }

  /// P3: pick a quick reply (or write one) and decline with it.
  Future<void> _declineWithText(PhoneCall call) async {
    final List<String> replies = await ref
        .read(quickRepliesProvider.future)
        .catchError((Object _) => QuickReplies.defaults);
    if (!mounted) return;
    final String? text = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheet) => _QuickReplySheet(replies: replies),
    );
    if (text == null || text.trim().isEmpty) return;
    await _control.rejectWithMessage(call.id, text.trim());
  }
}

class _QuickReplySheet extends StatefulWidget {
  const _QuickReplySheet({required this.replies});
  final List<String> replies;

  @override
  State<_QuickReplySheet> createState() => _QuickReplySheetState();
}

class _QuickReplySheetState extends State<_QuickReplySheet> {
  final TextEditingController _own = TextEditingController();

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              context.l10n.declineWithMessage,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final String r in widget.replies)
            ListTile(
              leading: const Icon(Icons.message_outlined),
              title: Text(r),
              onTap: () => Navigator.of(context).pop(r),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
            child: TextField(
              controller: _own,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: context.l10n.writeYourOwn,
                suffixIcon: IconButton(
                  tooltip: context.l10n.send,
                  icon: const Icon(Icons.send),
                  onPressed: () => Navigator.of(context).pop(_own.text),
                ),
              ),
              onSubmitted: (String v) => Navigator.of(context).pop(v),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Car mode (P11): only what's safe to tap while driving, extra large.
class _CarControls extends StatelessWidget {
  const _CarControls({
    required this.snapshot,
    required this.call,
    required this.control,
  });

  final CallsSnapshot snapshot;
  final PhoneCall call;
  final CallControl control;

  @override
  Widget build(BuildContext context) {
    final bool speaker = snapshot.route == AudioRoute.speaker;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _BigButton(
              icon: snapshot.muted ? Icons.mic_off : Icons.mic_none,
              label: snapshot.muted ? context.l10n.unmute : context.l10n.mute,
              on: snapshot.muted,
              onPressed: () => control.mute(!snapshot.muted),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: snapshot.hasBluetooth
                ? _BigButton(
                    icon: snapshot.route == AudioRoute.bluetooth
                        ? Icons.bluetooth_audio
                        : Icons.volume_up,
                    label: snapshot.route == AudioRoute.bluetooth
                        ? context.l10n.carAudio
                        : context.l10n.phoneAudio,
                    on: snapshot.route == AudioRoute.bluetooth,
                    onPressed: () => control.route(
                      snapshot.route == AudioRoute.bluetooth
                          ? AudioRoute.speaker
                          : AudioRoute.bluetooth,
                    ),
                  )
                : _BigButton(
                    icon: Icons.volume_up,
                    label: context.l10n.speaker,
                    on: speaker,
                    onPressed: () => control.route(
                      speaker ? AudioRoute.earpiece : AudioRoute.speaker,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.on = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool on;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: on,
    child: SizedBox(
      height: 96,
      child: on
          ? FilledButton.icon(
              icon: Icon(icon, size: 36),
              label: Text(label, style: const TextStyle(fontSize: 20)),
              onPressed: onPressed,
            )
          : FilledButton.tonalIcon(
              icon: Icon(icon, size: 36),
              label: Text(label, style: const TextStyle(fontSize: 20)),
              onPressed: onPressed,
            ),
    ),
  );
}

class _CallerHeader extends StatelessWidget {
  const _CallerHeader({required this.call, this.large = false});
  final PhoneCall call;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppL10n l = context.l10n;
    final String status = switch (call.state) {
      CallState.ringing => call.isVideo ? l.incomingVideoCall : l.incomingCall,
      CallState.selectAccount => l.chooseSim,
      CallState.dialing || CallState.connecting => l.calling,
      CallState.holding => l.onHold,
      CallState.disconnecting || CallState.disconnected => l.callEnded,
      CallState.active => _elapsed(l, call.connectedAt),
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
            style: large ? text.displaySmall : text.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
        if (call.name != null && call.number.isNotEmpty)
          Text(ltr(call.number), style: text.titleMedium),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: call.state != CallState.active,
          child: Text(status, style: text.titleMedium),
        ),
      ],
    );
  }

  static String _elapsed(AppL10n l, DateTime? since) {
    if (since == null) return l.connected;
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
              label: Text(context.l10n.callWithAccount(call.accounts[i])),
              onPressed: () => onPick(i),
            ),
          ),
        TextButton(onPressed: onCancel, child: Text(context.l10n.cancel)),
      ],
    ),
  );
}

class _IncomingActions extends StatelessWidget {
  const _IncomingActions({
    required this.onAnswer,
    required this.onDecline,
    required this.onEndAndAnswer,
    this.onAnswerVideo,
    this.onMessage,
    this.waiting = false,
  });
  final VoidCallback onAnswer;

  /// A video call: answer with video (the plain answer is voice only).
  final VoidCallback? onAnswerVideo;
  final VoidCallback onDecline;
  final VoidCallback onEndAndAnswer;
  final VoidCallback? onMessage;

  /// Another call is already up (call waiting).
  final bool waiting;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _RoundButton(
            color: Colors.red.shade600,
            icon: Icons.call_end,
            label: context.l10n.decline,
            onPressed: onDecline,
          ),
          if (waiting)
            _RoundButton(
              color: Colors.orange.shade700,
              icon: Icons.phone_forwarded,
              label: context.l10n.endAndAnswer,
              onPressed: onEndAndAnswer,
            ),
          _RoundButton(
            color: Colors.green.shade600,
            icon: waiting ? Icons.phone_paused : Icons.call,
            label: waiting
                ? context.l10n.holdAndAnswer
                : (onAnswerVideo != null
                      ? context.l10n.answerVoice
                      : context.l10n.answer),
            onPressed: onAnswer,
          ),
          if (onAnswerVideo != null && !waiting)
            _RoundButton(
              color: Colors.green.shade600,
              icon: Icons.videocam,
              label: context.l10n.answerVideo,
              onPressed: onAnswerVideo!,
            ),
        ],
      ),
      if (onMessage != null) ...<Widget>[
        const SizedBox(height: 16),
        TextButton.icon(
          icon: const Icon(Icons.message_outlined),
          label: Text(context.l10n.replyWithMessage),
          onPressed: onMessage,
        ),
      ],
    ],
  );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.snapshot,
    required this.call,
    required this.control,
    required this.onKeypad,
    required this.onVideo,
  });

  final CallsSnapshot snapshot;
  final PhoneCall call;
  final CallControl control;
  final VoidCallback onKeypad;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) {
    final bool speaker = snapshot.route == AudioRoute.speaker;
    final bool held = call.state == CallState.holding;
    final bool twoCalls = snapshot.secondary != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      // Four to a row on a phone, so RTT and video still fit in two rows.
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 16,
        children: <Widget>[
          _Toggle(
            icon: snapshot.muted ? Icons.mic_off : Icons.mic_none,
            label: context.l10n.mute,
            on: snapshot.muted,
            onTap: () => control.mute(!snapshot.muted),
          ),
          _Toggle(
            icon: Icons.dialpad,
            label: context.l10n.keypad,
            onTap: onKeypad,
          ),
          _Toggle(
            icon: snapshot.hasBluetooth
                ? (snapshot.route == AudioRoute.bluetooth
                      ? Icons.bluetooth_audio
                      : (speaker ? Icons.volume_up : Icons.phone_in_talk))
                : Icons.volume_up,
            label: snapshot.hasBluetooth
                ? context.l10n.audio
                : context.l10n.speaker,
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
              label: held ? context.l10n.resume : context.l10n.hold,
              on: held,
              onTap: () => control.hold(call.id, !held),
            ),
          if (twoCalls && call.canMerge)
            _Toggle(
              icon: Icons.call_merge,
              label: context.l10n.merge,
              onTap: control.merge,
            ),
          if (!twoCalls)
            _Toggle(
              icon: Icons.add_call,
              label: context.l10n.addCall,
              onTap: control.addCall,
            ),
          // P12: only when the carrier offers them on this call.
          if (call.canVideo && call.state == CallState.active)
            _Toggle(
              icon: Icons.videocam_outlined,
              label: context.l10n.video,
              onTap: onVideo,
            ),
          if (call.canRtt && !call.rttActive && call.state == CallState.active)
            _Toggle(
              icon: Icons.rtt,
              label: context.l10n.rtt,
              onTap: () => control.rttRequest(call.id),
            ),
        ],
      ),
    );
  }

  Future<void> _pickRoute(BuildContext context) async {
    final List<(int, IconData, String)> routes = <(int, IconData, String)>[
      if (snapshot.supportedRoutes & AudioRoute.bluetooth != 0)
        (AudioRoute.bluetooth, Icons.bluetooth_audio, context.l10n.bluetooth),
      if (snapshot.supportedRoutes & AudioRoute.wiredHeadset != 0)
        (AudioRoute.wiredHeadset, Icons.headset, context.l10n.headset)
      else if (snapshot.supportedRoutes & AudioRoute.earpiece != 0)
        (AudioRoute.earpiece, Icons.phone_in_talk, context.l10n.phoneEarpiece),
      (AudioRoute.speaker, Icons.volume_up, context.l10n.speaker),
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
      subtitle: Text(
        call.state == CallState.holding
            ? context.l10n.onHold
            : context.l10n.calling,
      ),
      trailing: TextButton(onPressed: onSwap, child: Text(context.l10n.swap)),
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
      width: 72,
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
    this.small = false,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Smaller, label hidden: the RTT chat needs the room.
  final bool small;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SizedBox(
        width: small ? 56 : 72,
        height: small ? 56 : 72,
        child: FloatingActionButton(
          heroTag: label,
          shape: const CircleBorder(),
          backgroundColor: color,
          foregroundColor: Colors.white,
          tooltip: label,
          onPressed: onPressed,
          child: Icon(icon, size: small ? 26 : 32),
        ),
      ),
      if (!small) ...<Widget>[const SizedBox(height: 8), Text(label)],
    ],
  );
}

/// A short note under the caller, when RTT or video couldn't start.
class _Notice extends StatelessWidget {
  const _Notice({required this.call});
  final PhoneCall call;

  @override
  Widget build(BuildContext context) {
    final String? text = switch (call.notice) {
      'rttFailed' => context.l10n.rttFailed,
      'videoFailed' => context.l10n.videoFailed,
      _ => null,
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

/// The other person asks to switch to RTT or video.
class _RequestBanner extends StatelessWidget {
  const _RequestBanner({
    required this.icon,
    required this.text,
    required this.onAccept,
    required this.onDecline,
  });

  final IconData icon;
  final String text;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.tertiaryContainer,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: <Widget>[
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Semantics(liveRegion: true, child: Text(text))),
          TextButton(onPressed: onDecline, child: Text(context.l10n.decline)),
          TextButton(onPressed: onAccept, child: Text(context.l10n.accept)),
        ],
      ),
    ),
  );
}

/// The caller in one line, with mute and speaker, above the RTT chat.
class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.call,
    required this.snapshot,
    required this.control,
  });

  final PhoneCall call;
  final CallsSnapshot snapshot;
  final CallControl control;

  @override
  Widget build(BuildContext context) {
    final AppL10n l = context.l10n;
    final bool speaker = snapshot.route == AudioRoute.speaker;
    final String status = switch (call.state) {
      CallState.active => _CallerHeader._elapsed(l, call.connectedAt),
      CallState.holding => l.onHold,
      _ => l.calling,
    };
    return ListTile(
      leading: ContactAvatar(label: call.name ?? '', radius: 20),
      title: Text(call.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${l.rtt} · $status'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: snapshot.muted ? l.unmute : l.mute,
            isSelected: snapshot.muted,
            icon: Icon(snapshot.muted ? Icons.mic_off : Icons.mic_none),
            onPressed: () => control.mute(!snapshot.muted),
          ),
          IconButton(
            tooltip: l.speaker,
            isSelected: speaker,
            icon: Icon(speaker ? Icons.volume_up : Icons.volume_up_outlined),
            onPressed: () => control.route(
              speaker ? AudioRoute.earpiece : AudioRoute.speaker,
            ),
          ),
        ],
      ),
    );
  }
}

/// Real-time text (P12): a chat where both sides see each letter as it's
/// typed. Text goes over the carrier's call, never to ZT servers, and is
/// not kept after the call.
class _RttPanel extends ConsumerStatefulWidget {
  const _RttPanel({required this.call});
  final PhoneCall call;

  @override
  ConsumerState<_RttPanel> createState() => _RttPanelState();
}

class _RttPanelState extends ConsumerState<_RttPanel> {
  late final TextEditingController _draft = TextEditingController(
    text: _sentDraft(),
  );
  final FocusNode _focus = FocusNode();

  /// What the other person already sees of this call's line, so the field
  /// and their screen stay the same when the panel is rebuilt.
  String _sentDraft() => ref.read(rttProvider)[widget.call.id]?.draft ?? '';

  @override
  void didUpdateWidget(_RttPanel old) {
    super.didUpdateWidget(old);
    if (old.call.id != widget.call.id) _draft.text = _sentDraft();
  }

  @override
  void dispose() {
    _draft.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    ref.read(rttProvider.notifier).submit(widget.call.id);
    _draft.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final AppL10n l = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<RttMessage> messages =
        ref.watch(rttProvider)[widget.call.id]?.messages ??
        const <RttMessage>[];
    return Column(
      children: <Widget>[
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l.rttHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (BuildContext context, int i) {
                    final RttMessage m = messages[messages.length - 1 - i];
                    return _RttBubble(message: m, latest: i == 0);
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('rtt-input'),
                  controller: _draft,
                  focusNode: _focus,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: l.rttTypeHere,
                    helperText: l.rttSeesTyping,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (String v) =>
                      ref.read(rttProvider.notifier).type(widget.call.id, v),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                tooltip: l.send,
                icon: const Icon(Icons.send),
                onPressed: _send,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RttBubble extends StatelessWidget {
  const _RttBubble({required this.message, required this.latest});
  final RttMessage message;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppL10n l = context.l10n;
    final bool me = message.fromMe;
    return Align(
      alignment: me
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Semantics(
          // Screen readers read the other person's words as they arrive.
          liveRegion: !me && latest,
          label: me ? l.rttYouSaid : l.rttTheySaid,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: me ? scheme.primaryContainer : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              message.done || message.text.isEmpty
                  ? message.text
                  : '${message.text} …',
              style: TextStyle(
                color: me ? scheme.onPrimaryContainer : scheme.onSurface,
                fontSize: 17,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A carrier video call (P12): their video fills the screen, ours sits in
/// a corner. Both are drawn by the phone's carrier stack into textures.
class _VideoCallView extends StatelessWidget {
  const _VideoCallView({
    required this.snapshot,
    required this.call,
    required this.control,
    required this.onCamera,
  });

  final CallsSnapshot snapshot;
  final PhoneCall call;
  final CallControl control;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final ThemeData dark = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Theme.of(context).colorScheme.primary,
        brightness: Brightness.dark,
      ),
    );
    final AppL10n l = context.l10n;
    final (int, int)? peer = call.peerSize;
    final (int, int)? own = call.previewSize;
    final String status = call.state == CallState.active
        ? _CallerHeader._elapsed(l, call.connectedAt)
        : l.calling;
    return Theme(
      data: dark,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (call.displayTexture != null && call.receivingVideo)
              Center(
                child: AspectRatio(
                  aspectRatio: peer == null ? 3 / 4 : peer.$1 / peer.$2,
                  child: Texture(
                    key: const ValueKey<String>('remote-video'),
                    textureId: call.displayTexture!,
                  ),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ContactAvatar(label: call.name ?? '', radius: 48),
                    const SizedBox(height: 12),
                    Text(
                      l.waitingForVideo,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                call.title,
                                style: dark.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                status,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              _Notice(call: call),
                            ],
                          ),
                        ),
                        if (call.previewTexture != null && call.sendingVideo)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 110,
                              child: AspectRatio(
                                // The camera's frames are landscape; the
                                // phone is upright.
                                aspectRatio: own == null
                                    ? 3 / 4
                                    : (own.$1 < own.$2
                                          ? own.$1 / own.$2
                                          : own.$2 / own.$1),
                                child: Texture(
                                  key: const ValueKey<String>('own-video'),
                                  textureId: call.previewTexture!,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 12,
                      children: <Widget>[
                        _Toggle(
                          icon: snapshot.muted ? Icons.mic_off : Icons.mic_none,
                          label: l.mute,
                          on: snapshot.muted,
                          onTap: () => control.mute(!snapshot.muted),
                        ),
                        _Toggle(
                          icon: call.sendingVideo
                              ? Icons.videocam
                              : Icons.videocam_off,
                          label: call.sendingVideo ? l.cameraOff : l.cameraOn,
                          on: !call.sendingVideo,
                          onTap: call.sendingVideo
                              ? () => control.videoCamera(call.id, false)
                              : onCamera,
                        ),
                        if (call.sendingVideo)
                          _Toggle(
                            icon: Icons.cameraswitch_outlined,
                            label: l.switchCamera,
                            onTap: () => control.videoSwitchCamera(call.id),
                          ),
                        _Toggle(
                          icon: Icons.phone_in_talk_outlined,
                          label: l.voiceOnly,
                          onTap: () => control.videoStop(call.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: _RoundButton(
                        color: Colors.red.shade600,
                        icon: Icons.call_end,
                        label: l.endCall,
                        onPressed: () => control.hangUp(call.id),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
