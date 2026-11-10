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
  );

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

  String get title => isConference
      ? 'Conference call'
      : (name?.isNotEmpty == true
            ? name!
            : (number.isEmpty ? 'Private number' : number));
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
    );
  }

  final List<PhoneCall> calls;
  final bool muted;
  final int route;
  final int supportedRoutes;

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
