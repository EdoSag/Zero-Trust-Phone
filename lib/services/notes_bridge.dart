import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// The ZT Notes app id, whose items are the notes.
const String notesAppId = 'notes';

/// The Notes app key of the unlocked account, derived at unlock like the
/// Tasks key and zeroed when the vault locks. Phone only adds notes with
/// it: notes written during a call (P27) and call transcripts (P20).
final notesKeyProvider = NotifierProvider<NotesKey, Uint8List?>(NotesKey.new);

class NotesKey extends Notifier<Uint8List?> {
  @override
  Uint8List? build() {
    ref.listen(vaultControllerProvider, (_, VaultState next) {
      if (next is VaultLocked) clear();
    });
    ref.onDispose(_zero);
    return null;
  }

  Future<void> deriveFrom(Uint8List dek) async {
    final Uint8List key = await KeyHierarchy.appKey(dek, notesAppId);
    _zero();
    state = key;
  }

  void clear() {
    _zero();
    state = null;
  }

  void _zero() {
    final Uint8List? key = state;
    key?.fillRange(0, key.length, 0);
  }
}

/// A new note as ZT Notes writes it (`Note.toItemJson`), so every Notes
/// version can read it.
Map<String, Object?> newNoteJson({
  required String title,
  required String body,
  required DateTime now,
}) => <String, Object?>{
  'title': title,
  'body': body,
  'notebookId': null,
  'tagIds': <String>[],
  'createdAt': now.toUtc().toIso8601String(),
};

/// Adds notes to ZT Notes in the same account. Phone keeps its own small
/// copy of the notes it wrote (opened with the Notes key) so a note added
/// offline is pushed later. It never reads or changes other notes.
class NotesBridge {
  NotesBridge(this.ref);
  final Ref ref;

  Future<T> _withEngine<T>(
    Future<T> Function(ItemSyncEngine engine, ZtLocalStore store) run,
  ) async {
    final Uint8List? unlocked = ref.read(notesKeyProvider);
    if (unlocked == null) throw const VaultIsLocked();
    final Uint8List key = Uint8List.fromList(unlocked);
    try {
      final String? userId = ref.read(accountServiceProvider).currentUserId;
      if (userId == null) throw StateError('Not signed in');
      final String path = await ZtLocalStore.pathFor(
        appId: 'phone_notes',
        userId: userId,
      );
      ZtLocalStore store;
      try {
        store = await ZtLocalStore.open(appKey: key, path: path);
      } on LocalStoreUnreadable {
        await ZtLocalStore.moveAside(path);
        store = await ZtLocalStore.open(appKey: key, path: path);
      }
      final ItemSyncEngine engine = await ItemSyncEngine.fromVault(
        appId: notesAppId,
        appKey: key,
        deviceId: await ref.read(ztDeviceIdProvider.future),
        store: store,
        backend: ref.read(ztSyncBackendProvider),
      );
      try {
        return await run(engine, store);
      } finally {
        await engine.close();
        await store.close();
      }
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  /// Adds a note and tries to send it. Returns its id.
  Future<String> add({required String title, required String body}) =>
      _withEngine((ItemSyncEngine engine, ZtLocalStore _) async {
        final Random r = Random.secure();
        final String id = List<String>.generate(
          32,
          (int i) => r.nextInt(16).toRadixString(16),
        ).join();
        await engine.save(
          id,
          newNoteJson(title: title, body: body, now: DateTime.now()),
        );
        try {
          await engine.sync();
        } on Object {
          // Offline: [flush] sends it later.
        }
        return id;
      });

  /// Sends notes saved while offline.
  Future<void> flush() async {
    if (ref.read(notesKeyProvider) == null) return;
    await _withEngine((ItemSyncEngine engine, ZtLocalStore store) async {
      if ((await store.dirtyItems()).isNotEmpty) {
        try {
          await engine.sync();
        } on Object {
          // Still offline.
        }
      }
    });
  }
}

final notesBridgeProvider = Provider<NotesBridge>((ref) => NotesBridge(ref));

/// A note written on the call screen (P27). The call screen runs while
/// the vault is locked, so the note waits in the phone's secure
/// preferences (Android Keystore) until ZT Phone is next unlocked, then
/// moves into ZT Notes and is deleted here.
class PendingCallNote {
  const PendingCallNote({
    required this.number,
    required this.name,
    required this.at,
    required this.text,
  });

  final String number;
  final String name;
  final DateTime at;
  final String text;

  Map<String, Object?> toJson() => <String, Object?>{
    'number': number,
    'name': name,
    'at': at.millisecondsSinceEpoch,
    'text': text,
  };

  static PendingCallNote? fromJson(Object? j) {
    if (j is! Map<Object?, Object?>) return null;
    final Object? at = j['at'];
    final Object? text = j['text'];
    if (at is! num || text is! String) return null;
    return PendingCallNote(
      number: j['number'] as String? ?? '',
      name: j['name'] as String? ?? '',
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
      text: text,
    );
  }
}

/// The notes waiting to move into ZT Notes.
class PendingCallNotes {
  PendingCallNotes(this._prefs);
  final PreferencesStore _prefs;
  static const String key = 'pending_call_notes';

  Future<List<PendingCallNote>> all() async {
    final String? raw = await _prefs.read(key);
    if (raw == null || raw.isEmpty) return const <PendingCallNote>[];
    try {
      return <PendingCallNote>[
        for (final Object? j in jsonDecode(raw) as List<Object?>)
          ?PendingCallNote.fromJson(j),
      ];
    } on Object {
      return const <PendingCallNote>[];
    }
  }

  Future<void> add(PendingCallNote note) async {
    final List<PendingCallNote> notes = <PendingCallNote>[...await all(), note];
    await _save(notes);
  }

  Future<void> _save(List<PendingCallNote> notes) => _prefs.write(
    key,
    jsonEncode(<Object?>[for (final PendingCallNote n in notes) n.toJson()]),
  );

  /// Moves every waiting note into ZT Notes with [addNote]; each one is
  /// removed here only once it's saved there. Returns how many moved.
  Future<int> moveInto(
    Future<void> Function(PendingCallNote note) addNote,
  ) async {
    final List<PendingCallNote> waiting = await all();
    if (waiting.isEmpty) return 0;
    final List<PendingCallNote> left = <PendingCallNote>[];
    int moved = 0;
    for (final PendingCallNote n in waiting) {
      try {
        await addNote(n);
        moved++;
      } on Object {
        left.add(n);
      }
    }
    await _save(left);
    return moved;
  }
}

final pendingCallNotesProvider = Provider<PendingCallNotes>(
  (ref) => PendingCallNotes(ref.watch(ztPreferencesStoreProvider)),
);

/// "My card" (P27): the text the call screen's "Text my card" sends, made
/// from a ZT Contacts card in Settings. In the phone's secure preferences
/// because the call screen runs locked.
final myCardProvider = AsyncNotifierProvider<MyCard, String?>(MyCard.new);

class MyCard extends AsyncNotifier<String?> {
  static const String key = 'my_card';

  @override
  Future<String?> build() async {
    final String? raw = await ref.read(ztPreferencesStoreProvider).read(key);
    return raw == null || raw.trim().isEmpty ? null : raw;
  }

  Future<void> set(String? text) async {
    state = AsyncData<String?>(text);
    await ref.read(ztPreferencesStoreProvider).write(key, text ?? '');
  }
}
