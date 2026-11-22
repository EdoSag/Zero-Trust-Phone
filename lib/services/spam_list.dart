import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

/// The key the weekly "Spam list" workflow signs lists with (Ed25519), the
/// same one ZT Browser's blocklist uses. Only a list signed with its
/// private half, kept as a GitHub Actions secret, is ever used: a changed
/// file on the download server is refused.
const String spamListPublicKey = 'HlsU7OZwBpMNRNqCFn++sn+GL6o+rEG1f8KOpO4V2mo=';

const String _base =
    'https://github.com/EdoSag/Zero-Trust-Phone/releases/download/spam-list';

/// The first line of every list. ZT Browser's lists start differently, so
/// one can never pass for the other although the key is shared.
const String spamListHeader = '# ZT Phone spam list, format 1.';

/// What happens to a call from a reported number (P24). Contacts are never
/// affected, and the stricter of this and the unknown-callers rule wins.
enum SpamMode { off, warn, silence, voicemail }

/// P24 setting, on this phone only (the screening service reads it while
/// the app is locked). Labels reported calls by default.
final spamModeProvider = NotifierProvider<SpamModeNotifier, SpamMode>(
  SpamModeNotifier.new,
);

class SpamModeNotifier extends Notifier<SpamMode> {
  static const String key = 'spam_mode';
  late Future<void> loaded;

  @override
  SpamMode build() {
    loaded = _load();
    return SpamMode.warn;
  }

  Future<void> _load() async {
    try {
      final String? raw = await ref.read(ztPreferencesStoreProvider).read(key);
      state = SpamMode.values.firstWhere(
        (SpamMode m) => m.name == raw,
        orElse: () => SpamMode.warn,
      );
    } on Object {
      // Unreadable: the default.
    }
  }

  Future<void> set(SpamMode mode) async {
    await loaded;
    state = mode;
    await ref.read(ztPreferencesStoreProvider).write(key, mode.name);
    await ref.read(telecomProvider).setSpamMode(mode.name);
  }
}

/// The result of an update check, for the settings screen.
enum SpamListCheck { updated, upToDate, notDue, failed, off }

/// Fetches files over HTTPS; fakeable in tests.
typedef Fetch = Future<List<int>?> Function(Uri url, int maxBytes);

Future<List<int>?> _httpGet(Uri url, int maxBytes) async {
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);
  try {
    final HttpClientRequest req = await client.getUrl(url);
    final HttpClientResponse res = await req.close().timeout(
      const Duration(seconds: 30),
    );
    if (res.statusCode != 200) return null;
    final BytesBuilder out = BytesBuilder(copy: false);
    await for (final List<int> chunk in res.timeout(
      const Duration(minutes: 2),
    )) {
      out.add(chunk);
      if (out.length > maxBytes) return null;
    }
    return out.takeBytes();
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Keeps the reported-spam list fresh: once a week it downloads the newest
/// list from ZT Phone's own GitHub releases, checks its signature, and
/// hands it to the Android side, which looks numbers up on the phone.
/// Nothing about you or your calls is sent: it's a plain download.
class SpamListUpdater {
  SpamListUpdater(
    this._telecom,
    this._prefs, {
    Fetch? fetch,
    String publicKey = spamListPublicKey,
  }) : _fetch = fetch ?? _httpGet,
       _publicKey = base64.decode(publicKey);

  final Telecom _telecom;
  final PreferencesStore _prefs;
  final Fetch _fetch;
  final List<int> _publicKey;

  static const Duration every = Duration(days: 7);
  static const String lastCheckKey = 'spam_list_checked_at';
  static const String dateKey = 'spam_list_date';
  static const int _maxBytes = 8 * 1024 * 1024;

  Future<DateTime?> lastCheck() async {
    final int? ms = int.tryParse(await _prefs.read(lastCheckKey) ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// The date of the list in use (yyyy-mm-ddThh:mm UTC), if any.
  Future<String?> listDate() => _prefs.read(dateKey);

  /// Checks for a newer list when a week has passed (or [force]).
  Future<SpamListCheck> checkIfDue(SpamMode mode, {bool force = false}) async {
    if (mode == SpamMode.off) return SpamListCheck.off;
    final DateTime now = DateTime.now();
    final DateTime? last = await lastCheck();
    if (!force && last != null && now.difference(last) < every) {
      return SpamListCheck.notDue;
    }
    SpamListCheck result;
    try {
      result = await _update();
    } on Object {
      result = SpamListCheck.failed;
    }
    if (result != SpamListCheck.failed) {
      await _prefs.write(lastCheckKey, '${now.millisecondsSinceEpoch}');
    }
    return result;
  }

  Future<SpamListCheck> _update() async {
    final List<int>? sig = await _fetch(
      Uri.parse('$_base/spam-list.txt.gz.sig'),
      1024,
    );
    if (sig == null) return SpamListCheck.failed;
    final List<int>? gz = await _fetch(
      Uri.parse('$_base/spam-list.txt.gz'),
      _maxBytes,
    );
    if (gz == null) return SpamListCheck.failed;
    final String? text = await verifiedList(
      gz,
      utf8.decode(sig, allowMalformed: true).trim(),
      _publicKey,
    );
    if (text == null) return SpamListCheck.failed;
    final String? date = listDateOf(text);
    if (date == null) return SpamListCheck.failed;
    final String current = await _prefs.read(dateKey) ?? '';
    if (date.compareTo(current) <= 0) return SpamListCheck.upToDate;
    if (!await _telecom.installSpamList(text)) return SpamListCheck.failed;
    await _prefs.write(dateKey, date);
    return SpamListCheck.updated;
  }

  /// The list inside [gz] when [signatureBase64] is a valid signature of
  /// it by [publicKey] and it is a ZT Phone spam list; otherwise null.
  static Future<String?> verifiedList(
    List<int> gz,
    String signatureBase64,
    List<int> publicKey,
  ) async {
    final List<int> sigBytes;
    try {
      sigBytes = base64.decode(signatureBase64);
    } on FormatException {
      return null;
    }
    if (sigBytes.length != 64 || publicKey.length != 32) return null;
    final bool ok = await Ed25519().verify(
      gz,
      signature: Signature(
        sigBytes,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      ),
    );
    if (!ok) return null;
    final List<int> raw;
    try {
      raw = gzip.decode(gz);
    } on FormatException {
      return null;
    }
    if (raw.length > 4 * _maxBytes) return null;
    final String text = utf8.decode(raw, allowMalformed: true);
    if (!text.startsWith('$spamListHeader\n')) return null;
    return text;
  }

  /// The `# list-date:` of a list (yyyy-mm-ddThh:mm, UTC).
  static String? listDateOf(String text) =>
      RegExp(r'^# list-date: ([0-9T:-]{10,16})$', multiLine: true)
          .firstMatch(
            text.substring(0, text.length < 2000 ? text.length : 2000),
          )
          ?.group(1);
}

final spamListUpdaterProvider = Provider<SpamListUpdater>(
  (ref) => SpamListUpdater(
    ref.read(telecomProvider),
    ref.read(ztPreferencesStoreProvider),
  ),
);
