import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One row of Android's call history.
class CallLogEntry {
  const CallLogEntry({
    required this.id,
    required this.number,
    required this.type,
    required this.date,
    required this.duration,
    this.cachedName,
    this.isNew = false,
    this.privateId,
  });

  factory CallLogEntry.fromMap(Map<Object?, Object?> m) => CallLogEntry(
    id: (m['id'] as num).toInt(),
    number: (m['number'] as String?) ?? '',
    type: CallType.fromAndroid((m['type'] as num?)?.toInt() ?? 0),
    date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num).toInt()),
    duration: Duration(seconds: (m['duration'] as num?)?.toInt() ?? 0),
    cachedName: m['cachedName'] as String?,
    isNew: m['isNew'] == true,
  );

  /// `CallLog.Calls.TYPE`, for the backup.
  int get androidType => switch (type) {
    CallType.incoming => 1,
    CallType.outgoing => 2,
    CallType.missed => 3,
    CallType.voicemail => 4,
    CallType.rejected => 5,
    CallType.blocked => 6,
    CallType.other => 1,
  };

  final int id;
  final String number;
  final CallType type;
  final DateTime date;
  final Duration duration;

  /// The name Android saved with the call (from the phone's contacts).
  final String? cachedName;
  final bool isNew;

  /// P23: a private contact's call, kept only in the vault under this id
  /// (not in Android's call log; [id] is then 0).
  final String? privateId;

  bool get isPrivate => privateId != null;
}

enum CallType {
  incoming,
  outgoing,
  missed,
  voicemail,
  rejected,
  blocked,
  other;

  /// `CallLog.Calls.TYPE` values.
  static CallType fromAndroid(int t) => switch (t) {
    1 => incoming,
    2 => outgoing,
    3 => missed,
    4 => voicemail,
    5 => rejected,
    6 => blocked,
    _ => other,
  };
}

/// Call features the SIMs offer (P12).
class CallFeatures {
  const CallFeatures({
    this.rtt = false,
    this.video = false,
    this.systemSettings = false,
  });

  /// Real-time text: needs the carrier, and on many phones Android's own
  /// RTT switch.
  final bool rtt;

  /// Carrier video calls (ViLTE): needs VoLTE and the carrier's video
  /// calling turned on.
  final bool video;

  /// The built-in Phone app has a TTY / RTT settings screen.
  final bool systemSettings;
}

/// A SIM or other account calls can go out on.
class PhoneAccount {
  const PhoneAccount({required this.id, required this.label});
  final String id;
  final String label;
}

/// Android's phone side: the default Phone app role, placing calls, call
/// history and blocked numbers. Fakeable in tests.
class Telecom {
  Telecom([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('zt_phone/telecom');

  final MethodChannel _channel;

  /// Ticks when a DIAL or tel: link arrives while the app is open; the
  /// number itself waits on the Android side until [consumeDial] takes it.
  final ValueNotifier<int> dialRequests = ValueNotifier<int>(0);

  /// Ticks when the missed-call notification is tapped while the app is open.
  final ValueNotifier<int> recentsRequests = ValueNotifier<int>(0);

  /// Ticks when "Remind me" on a missed call is tapped while the app is open.
  final ValueNotifier<int> callBackRequests = ValueNotifier<int>(0);

  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  void listenForDials() {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'dialPending') dialRequests.value++;
      if (call.method == 'recentsPending') recentsRequests.value++;
      if (call.method == 'callBackPending') callBackRequests.value++;
    });
  }

  Future<T?> _call<T>(String method, [Object? args]) async {
    if (!isSupported) return null;
    return _channel.invokeMethod<T>(method, args);
  }

  Future<bool> isDefaultDialer() async =>
      await _call<bool>('isDefaultDialer') ?? false;

  Future<bool> requestDefaultDialer() async =>
      await _call<bool>('requestDefaultDialer') ?? false;

  Future<bool> requestPermissions() async =>
      await _call<bool>('requestPermissions') ?? false;

  Future<bool> hasPermission(String permission) async =>
      await _call<bool>('hasPermission', {'permission': permission}) ?? false;

  /// A number the app was opened with (DIAL or tel: link), "" for an empty
  /// dialpad, null when it was opened normally.
  Future<String?> consumeDial() => _call<String>('consumeDial');

  /// Text the app was opened with from another app's text menu or share
  /// sheet, to find a number in (P13). Taken right after [consumeDial].
  Future<String?> consumeDialText() => _call<String>('consumeDialText');

  /// Calls [number], on the SIM with [account] id when given (P6).
  /// [rtt] starts the call with real-time text, [video] as a carrier
  /// video call (P12); the carrier drops either if it can't. [hideCallerId]
  /// asks the carrier not to show my number for this call (P22). [number]
  /// may carry pauses and tones after it (`,` `;`, P15).
  Future<void> placeCall(
    String number, {
    String? account,
    bool rtt = false,
    bool video = false,
    bool hideCallerId = false,
  }) => _call<void>('placeCall', {
    'number': number,
    'account': account,
    'rtt': rtt,
    'video': video,
    'hideCallerId': hideCallerId,
  });

  /// The SIM's country as an ISO code ("IL"), or the network's, or null.
  Future<String?> simCountry() async {
    final String? iso = await _call<String>('simCountry');
    return iso == null || iso.isEmpty ? null : iso.toUpperCase();
  }

  /// What this phone's SIMs offer (P12).
  Future<CallFeatures> callFeatures() async {
    final Map<Object?, Object?>? m = await _call<Map<Object?, Object?>>(
      'callFeatures',
    );
    return CallFeatures(
      rtt: m?['rtt'] == true,
      video: m?['video'] == true,
      systemSettings: m?['systemSettings'] == true,
    );
  }

  /// Opens the built-in Phone app's TTY and RTT settings. False if the
  /// phone has none.
  Future<bool> openCallAccessibilitySettings() async =>
      await _call<bool>('openCallAccessibilitySettings') ?? false;

  /// Asks for the camera, for video calls. True when allowed.
  Future<bool> requestCamera() async =>
      await _call<bool>('requestCamera') ?? false;

  /// Calls the SIM's voicemail number (P5).
  Future<void> callVoicemail() => _call<void>('callVoicemail');

  Future<void> voicemailSettings() => _call<void>('voicemailSettings');

  /// Whether the app was opened from the missed-call notification.
  Future<bool> consumeShowRecents() async =>
      await _call<bool>('consumeShowRecents') ?? false;

  /// The SIMs this phone can call with.
  Future<List<PhoneAccount>> phoneAccounts() async => <PhoneAccount>[
    for (final Object? a
        in await _call<List<Object?>>('phoneAccounts') ?? <Object?>[])
      if (a is Map<Object?, Object?>)
        PhoneAccount(id: '${a['id']}', label: '${a['label']}'),
  ];

  /// What on-device call screening needs while the vault is locked (P1,
  /// P7). The Android side keeps only keyed hashes of the numbers.
  Future<void> setScreening({
    required String unknownMode,
    required bool blockHidden,
    required List<String> prefixes,
    required List<String> contactKeys,
    required List<String> voicemailKeys,
    required Map<String, String> ringtones,
    List<String> privateKeys = const <String>[],
  }) => _call<void>('setScreening', {
    'unknownMode': unknownMode,
    'blockHidden': blockHidden,
    'prefixes': prefixes,
    'contactKeys': contactKeys,
    'voicemailKeys': voicemailKeys,
    'ringtones': ringtones,
    'privateKeys': privateKeys,
  });

  /// P23: private contacts' calls the Android side took out of the shared
  /// call log, to move into the vault. They're kept there until
  /// [ackPrivateCalls] confirms the vault has them.
  Future<List<Map<Object?, Object?>>> takePrivateCalls() async =>
      <Map<Object?, Object?>>[
        for (final Object? c
            in await _call<List<Object?>>('takePrivateCalls') ?? <Object?>[])
          if (c is Map<Object?, Object?>) c,
      ];

  /// Tells the Android side these private calls ("number|date") are saved
  /// in the vault, so it can forget them.
  Future<void> ackPrivateCalls(List<String> keys) =>
      _call<void>('ackPrivateCalls', {'keys': keys});

  /// P25: a reminder notification at [at] to call [number] back.
  /// Replaces one with the same [id].
  Future<void> scheduleCallBack(String id, String number, DateTime at) =>
      _call<void>('scheduleCallBack', {
        'id': id,
        'number': number,
        'at': at.millisecondsSinceEpoch,
      });

  /// Whether call back reminders ring on the minute ("Alarms & reminders"
  /// allowed), and whether ZT Phone already asked. Null when unknown.
  Future<ExactAlarmState?> exactAlarmState() async {
    try {
      final Map<Object?, Object?>? m = await _call<Map<Object?, Object?>>(
        'exactAlarmState',
      );
      if (m == null) return null;
      return ExactAlarmState(
        exact: m['exact'] == true,
        asked: m['asked'] == true,
      );
    } on Object {
      return null;
    }
  }

  Future<void> markExactAlarmsAsked() => _call<void>('markExactAlarmsAsked');

  /// Opens Android's "Alarms & reminders" page for ZT Phone.
  Future<bool> openExactAlarmSettings() async =>
      await _call<bool>('openExactAlarmSettings') ?? false;

  Future<void> cancelCallBack(String id) =>
      _call<void>('cancelCallBack', {'id': id});

  /// A number from the missed-call notification's "Remind me" button, to
  /// pick a time for (P25). Null when there's none.
  Future<String?> consumeCallBackLater() =>
      _call<String>('consumeCallBackLater');

  Future<void> clearScreeningContacts() =>
      _call<void>('clearScreeningContacts');

  /// Adds calls to Android's call history, skipping ones it already has.
  Future<int> insertCalls(List<Map<String, Object?>> calls) async =>
      await _call<int>('insertCalls', {'calls': calls}) ?? 0;

  /// Android's ringtone picker. "" = the phone's ringtone, null = cancelled.
  Future<String?> pickRingtone({String? current}) =>
      _call<String>('pickRingtone', {'current': current});

  Future<String?> ringtoneTitle(String uri) =>
      _call<String>('ringtoneTitle', {'uri': uri});

  /// Opens "add contact" with the number filled in.
  Future<void> addContact(String number) =>
      _call<void>('addContact', {'number': number});

  Future<List<CallLogEntry>> callLog({int limit = 500}) async {
    final List<Object?> rows =
        await _call<List<Object?>>('callLog', {'limit': limit}) ?? <Object?>[];
    return <CallLogEntry>[
      for (final Object? r in rows)
        if (r is Map<Object?, Object?>) CallLogEntry.fromMap(r),
    ];
  }

  Future<int> deleteCalls(List<int> ids) async =>
      await _call<int>('deleteCalls', {'ids': ids}) ?? 0;

  Future<int> deleteCallsBefore(DateTime before) async =>
      await _call<int>('deleteCallsBefore', {
        'before': before.millisecondsSinceEpoch,
      }) ??
      0;

  Future<void> markMissedSeen() => _call<void>('markMissedSeen');

  Future<bool> canBlock() async => await _call<bool>('canBlock') ?? false;

  Future<List<String>> blockedNumbers() async =>
      (await _call<List<Object?>>('blockedNumbers') ?? <Object?>[])
          .whereType<String>()
          .toList();

  Future<void> block(String number) => _call<void>('block', {'number': number});

  Future<void> unblock(String number) =>
      _call<void>('unblock', {'number': number});

  /// Caller names for the in-call screen, kept in memory only.
  Future<void> setVaultNames(Map<String, String> names) =>
      _call<void>('setVaultNames', names);

  Future<void> clearVaultNames() => _call<void>('clearVaultNames');

  /// Notification words in the app's language, for the Android side
  /// (NativeStrings.kt), which shows them while Flutter isn't running.
  Future<void> setNativeStrings(Map<String, String> strings) =>
      _call<void>('setNativeStrings', strings);

  /// Whether incoming calls can show their card and open over the lock
  /// screen (notifications and, on Android 14+, full-screen alerts on).
  Future<bool> callAlertsReady() async =>
      await _call<bool>('callAlertsReady') ?? true;

  /// Opens the system screen that turns call alerts back on.
  Future<void> fixCallAlerts() => _call<void>('fixCallAlerts');
}

final telecomProvider = Provider<Telecom>((ref) => Telecom());

/// Whether ZT Phone is the default Phone app. Refresh with
/// `ref.invalidate(defaultDialerProvider)`.
final defaultDialerProvider = FutureProvider<bool>(
  (ref) => ref.watch(telecomProvider).isDefaultDialer(),
);

/// See [Telecom.callAlertsReady]. Refreshed with [defaultDialerProvider].
final callAlertsReadyProvider = FutureProvider<bool>((ref) async {
  ref.watch(defaultDialerProvider);
  final Telecom telecom = ref.watch(telecomProvider);
  return !telecom.isSupported || await telecom.callAlertsReady();
});

/// What the SIMs offer: RTT, carrier video calls. Refresh with
/// `ref.invalidate`.
final callFeaturesProvider = FutureProvider<CallFeatures>((ref) async {
  final Telecom telecom = ref.watch(telecomProvider);
  if (!telecom.isSupported) return const CallFeatures();
  try {
    return await telecom.callFeatures();
  } on PlatformException {
    return const CallFeatures();
  }
});

/// The country calls are made from (the SIM's), for the country hint
/// (P16). Null when unknown.
final homeCountryProvider = FutureProvider<String?>((ref) async {
  final Telecom telecom = ref.watch(telecomProvider);
  if (!telecom.isSupported) return null;
  try {
    return await telecom.simCountry();
  } on Object {
    // No SIM, or the platform side isn't there (tests).
    return null;
  }
});

/// The call history, newest first. Refresh with `ref.invalidate`.
final callLogProvider = FutureProvider<List<CallLogEntry>>(
  (ref) => ref.watch(telecomProvider).callLog(),
);

/// See [Telecom.exactAlarmState].
class ExactAlarmState {
  const ExactAlarmState({required this.exact, required this.asked});
  final bool exact;
  final bool asked;
}
