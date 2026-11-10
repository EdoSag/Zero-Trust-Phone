import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// Texts to send when declining a call (P3). Kept in the phone's secure
/// preferences, not the vault, because the call screen runs while the app
/// is locked.
class QuickReplies extends AsyncNotifier<List<String>> {
  static const String key = 'quick_replies';

  static const List<String> defaults = <String>[
    'Can\'t talk now. I\'ll call you back.',
    'I\'m driving. I\'ll call you soon.',
    'In a meeting. Can you text me?',
    'On my way.',
  ];

  @override
  Future<List<String>> build() async {
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
