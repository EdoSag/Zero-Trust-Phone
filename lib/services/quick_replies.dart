import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// Texts to send when declining a call (P3). Kept in the phone's secure
/// preferences, not the vault, because the call screen runs while the app
/// is locked.
class QuickReplies extends AsyncNotifier<List<String>> {
  static const String key = 'quick_replies';

  /// The starting replies, in the app's language until the user edits them.
  static List<String> get defaults => defaultsIn(currentL10n);

  static List<String> defaultsIn(AppL10n l) {
    return <String>[
      l.replyCantTalk,
      l.replyDriving,
      l.replyMeeting,
      l.replyOnMyWay,
    ];
  }

  @override
  Future<List<String>> build() async {
    // Unedited replies follow the language picked in Settings.
    final List<String> defaults = defaultsIn(
      appL10nFor(ref.watch(ztLanguageProvider)),
    );
    final String? raw = await ref.read(ztPreferencesStoreProvider).read(key);
    if (raw == null) return defaults;
    try {
      return <String>[
        for (final Object? s in jsonDecode(raw) as List<Object?>)
          if (s is String && s.trim().isNotEmpty) s,
      ];
    } on Object {
      return defaults;
    }
  }

  Future<void> save(List<String> replies) async {
    final List<String> clean = <String>[
      for (final String s in replies)
        if (s.trim().isNotEmpty) s.trim(),
    ];
    state = AsyncData<List<String>>(clean);
    await ref.read(ztPreferencesStoreProvider).write(key, jsonEncode(clean));
  }
}

final quickRepliesProvider = AsyncNotifierProvider<QuickReplies, List<String>>(
  QuickReplies.new,
);
