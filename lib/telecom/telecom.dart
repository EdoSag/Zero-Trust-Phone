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

  final int id;
  final String number;
  final CallType type;
  final DateTime date;
  final Duration duration;

  /// The name Android saved with the call (from the phone's contacts).
  final String? cachedName;
  final bool isNew;
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

/// Android's phone side: the default Phone app role, placing calls, call
/// history and blocked numbers. Fakeable in tests.
class Telecom {
  Telecom([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('zt_phone/telecom');

  final MethodChannel _channel;

  /// Ticks when a DIAL or tel: link arrives while the app is open; the
  /// number itself waits on the Android side until [consumeDial] takes it.
  final ValueNotifier<int> dialRequests = ValueNotifier<int>(0);

  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  void listenForDials() {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'dialPending') dialRequests.value++;
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

  Future<void> placeCall(String number) =>
      _call<void>('placeCall', {'number': number});

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
}

final telecomProvider = Provider<Telecom>((ref) => Telecom());

/// Whether ZT Phone is the default Phone app. Refresh with
/// `ref.invalidate(defaultDialerProvider)`.
final defaultDialerProvider = FutureProvider<bool>(
  (ref) => ref.watch(telecomProvider).isDefaultDialer(),
);

/// The call history, newest first. Refresh with `ref.invalidate`.
final callLogProvider = FutureProvider<List<CallLogEntry>>(
  (ref) => ref.watch(telecomProvider).callLog(),
);
