import 'package:zerotrust_phone/l10n/l10n.dart';

/// The calls the in-call screen shows, as sent by CallManager.kt.
class PhoneCall {
  const PhoneCall({
    required this.id,
    required this.number,
    required this.state,
    this.name,
    this.connectedAt,
    this.isConference = false,
    this.parentId,
    this.canHold = false,
    this.canMerge = false,
    this.canSwap = false,
    this.accounts = const <String>[],
    this.rttActive = false,
    this.canRtt = false,
    this.rttRequest = false,
    this.canVideo = false,
    this.videoState = VideoState.audioOnly,
    this.displayTexture,
    this.previewTexture,
    this.peerSize,
    this.previewSize,
    this.videoRequest = false,
    this.backCamera = false,
    this.cameraOff = false,
    this.cameraAllowed = false,
    this.notice,
  });

  factory PhoneCall.fromMap(Map<Object?, Object?> m) => PhoneCall(
    id: m['id']! as String,
    number: (m['number'] as String?) ?? '',
    name: m['name'] as String?,
    state: CallState.parse(m['state'] as String?),
    connectedAt: (m['connectedAt'] as num?) == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (m['connectedAt']! as num).toInt(),
          ),
    isConference: m['isConference'] == true,
    parentId: m['parentId'] as String?,
    canHold: m['canHold'] == true,
    canMerge: m['canMerge'] == true,
    canSwap: m['canSwap'] == true,
    accounts: <String>[
      for (final Object? a in (m['accounts'] as List<Object?>?) ?? <Object?>[])
        if (a is String) a,
    ],
    rttActive: m['rttActive'] == true,
    canRtt: m['canRtt'] == true,
    rttRequest: m['rttRequest'] == true,
    canVideo: m['canVideo'] == true,
    videoState: (m['videoState'] as num?)?.toInt() ?? VideoState.audioOnly,
    displayTexture: (m['displayTexture'] as num?)?.toInt(),
    previewTexture: (m['previewTexture'] as num?)?.toInt(),
    peerSize: _size(m['peerWidth'], m['peerHeight']),
    previewSize: _size(m['previewWidth'], m['previewHeight']),
    videoRequest: m['videoRequest'] == true,
    backCamera: m['backCamera'] == true,
    cameraOff: m['cameraOff'] == true,
    cameraAllowed: m['cameraAllowed'] == true,
    notice: m['notice'] as String?,
  );

  static (int, int)? _size(Object? w, Object? h) {
    final int width = (w as num?)?.toInt() ?? 0;
    final int height = (h as num?)?.toInt() ?? 0;
    return width > 0 && height > 0 ? (width, height) : null;
  }

  final String id;
  final String number;
  final String? name;
  final CallState state;
  final DateTime? connectedAt;
  final bool isConference;
  final String? parentId;
  final bool canHold;
  final bool canMerge;
  final bool canSwap;

  /// SIM names to pick from, in order, while [state] is selectAccount.
  final List<String> accounts;

  /// Real-time text (P12) is on: both sides see each letter as it's typed.
  final bool rttActive;

  /// The SIM's carrier offers RTT, so it can be turned on in this call.
  final bool canRtt;

  /// The other person asked to switch to RTT.
  final bool rttRequest;

  /// The call can be upgraded to a carrier video call.
  final bool canVideo;

  /// `VideoProfile` state bits ([VideoState]).
  final int videoState;

  /// Flutter textures the carrier draws into: their video, our camera.
  final int? displayTexture;
  final int? previewTexture;
  final (int, int)? peerSize;
  final (int, int)? previewSize;

  /// The other person asked to turn video on.
  final bool videoRequest;
  final bool backCamera;

  /// The user turned the camera off. It stays off even when the carrier
  /// refuses the change and the call still counts as sending video.
  final bool cameraOff;
  final bool cameraAllowed;

  /// "rttFailed" or "videoFailed", for a few seconds.
  final String? notice;

  bool get isVideo => VideoState.isVideo(videoState);
  bool get sendingVideo =>
      !cameraOff &&
      videoState & VideoState.tx != 0 &&
      videoState & VideoState.paused == 0;
  bool get receivingVideo => videoState & VideoState.rx != 0;

  String get title => isConference
      ? currentL10n.conferenceCall
      : (name?.isNotEmpty == true
            ? name!
            : (number.isEmpty ? currentL10n.privateNumber : ltr(number)));
}

enum CallState {
  ringing,

  /// Waiting for the user to pick a SIM ([PhoneCall.accounts]).
  selectAccount,
  dialing,
  connecting,
  active,
  holding,
  disconnecting,
  disconnected,
  other;

  static CallState parse(String? s) => switch (s) {
    'ringing' => ringing,
    'dialing' || 'new' => dialing,
    'selectAccount' => selectAccount,
    'connecting' => connecting,
    'active' => active,
    'holding' => holding,
    'disconnecting' => disconnecting,
    'disconnected' => disconnected,
    _ => other,
  };
}

/// `VideoProfile` states.
abstract final class VideoState {
  static const int audioOnly = 0;
  static const int tx = 1;
  static const int rx = 2;
  static const int bidirectional = 3;
  static const int paused = 4;

  static bool isVideo(int state) => state & bidirectional != 0;
}

/// `CallAudioState` routes.
abstract final class AudioRoute {
  static const int earpiece = 1;
  static const int bluetooth = 2;
  static const int wiredHeadset = 4;
  static const int speaker = 8;
}

class CallsSnapshot {
  const CallsSnapshot({
    this.calls = const <PhoneCall>[],
    this.muted = false,
    this.route = AudioRoute.earpiece,
    this.supportedRoutes = AudioRoute.earpiece | AudioRoute.speaker,
    this.carMode = false,
  });

  factory CallsSnapshot.fromMap(Map<Object?, Object?> m) {
    final Map<Object?, Object?>? audio = m['audio'] as Map<Object?, Object?>?;
    return CallsSnapshot(
      calls: <PhoneCall>[
        for (final Object? c in (m['calls'] as List<Object?>?) ?? <Object?>[])
          if (c is Map<Object?, Object?>) PhoneCall.fromMap(c),
      ],
      muted: audio?['muted'] == true,
      route: (audio?['route'] as num?)?.toInt() ?? AudioRoute.earpiece,
      supportedRoutes:
          (audio?['supportedRoutes'] as num?)?.toInt() ??
          (AudioRoute.earpiece | AudioRoute.speaker),
      carMode: m['carMode'] == true,
    );
  }

  final List<PhoneCall> calls;
  final bool muted;
  final int route;
  final int supportedRoutes;

  /// Android Auto, a car dock or driving mode: bigger, fewer buttons (P11).
  final bool carMode;

  /// Top-level calls (conference members are inside their conference).
  List<PhoneCall> get topLevel =>
      calls.where((PhoneCall c) => c.parentId == null).toList();

  PhoneCall? get ringing =>
      calls.where((PhoneCall c) => c.state == CallState.ringing).firstOrNull;

  /// The call the screen is about: ringing, else live, else on hold.
  PhoneCall? get primary {
    final List<PhoneCall> top = topLevel;
    for (final CallState s in <CallState>[
      CallState.ringing,
      CallState.selectAccount,
      CallState.active,
      CallState.dialing,
      CallState.connecting,
      CallState.holding,
      CallState.disconnecting,
    ]) {
      final PhoneCall? c = top.where((PhoneCall c) => c.state == s).firstOrNull;
      if (c != null) return c;
    }
    return top.firstOrNull;
  }

  /// The other call while two are up (one on hold).
  PhoneCall? get secondary {
    final PhoneCall? p = primary;
    return topLevel
        .where(
          (PhoneCall c) => c.id != p?.id && c.state != CallState.disconnected,
        )
        .firstOrNull;
  }

  bool get hasBluetooth => supportedRoutes & AudioRoute.bluetooth != 0;
}
