import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// The ZT Tasks app id, whose items are the to-do list.
const String tasksAppId = 'tasks';

/// The Tasks app key of the unlocked account, derived at unlock like the
/// Contacts key and zeroed when the vault locks. Phone only adds call back
/// tasks and ticks them off (P25).
final tasksKeyProvider = NotifierProvider<TasksKey, Uint8List?>(TasksKey.new);

class TasksKey extends Notifier<Uint8List?> {
  @override
  Uint8List? build() {
    ref.listen(vaultControllerProvider, (_, VaultState next) {
      if (next is VaultLocked) clear();
    });
    ref.onDispose(_zero);
    return null;
  }

  Future<void> deriveFrom(Uint8List dek) async {
    final Uint8List key = await KeyHierarchy.appKey(dek, tasksAppId);
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

/// A task as ZT Tasks writes it (its `Task.toJson`, schema version 1).
Map<String, Object?> callBackTaskJson({
  required String id,
  required String title,
  required String number,
  required DateTime due,
  required DateTime now,
  String? contactId,
}) => <String, Object?>{
  'id': id,
  'title': title,
  'description': null,
  'category': null,
  'priority': 'medium',
  'startDate': null,
  'dueDate': due.toIso8601String(),
  // ZT Phone itself reminds at [due]; a second reminder from ZT Tasks
  // would ring twice.
  'reminderAt': null,
  'recurrence': null,
  'tags': <String>[],
  'notes': number,
  'links': <String>['tel:${number.replaceAll(RegExp(r'[^0-9+*#]'), '')}'],
  'isCompleted': false,
  'isArchived': false,
  'deletedAt': null,
  'completedAt': null,
  'subTasks': <Object?>[],
  'createdAt': now.toIso8601String(),
  'updatedAt': now.toIso8601String(),
  if (contactId != null) 'contactIds': <String>[contactId],
  ZtCollection.versionKey: 1,
};

/// Writes into ZT Tasks' encrypted items in the same account: Phone keeps
/// its own small copy of the to-do list (opened with the Tasks key) so a
/// task added offline is pushed later.
class TasksBridge {
  TasksBridge(this.ref);
  final Ref ref;

  Future<T> _withEngine<T>(
    Future<T> Function(ItemSyncEngine engine, ZtLocalStore store) run,
  ) async {
    final Uint8List? unlocked = ref.read(tasksKeyProvider);
    if (unlocked == null) throw const VaultIsLocked();
    final Uint8List key = Uint8List.fromList(unlocked);
    try {
      final String? userId = ref.read(accountServiceProvider).currentUserId;
      if (userId == null) throw StateError('Not signed in');
      final String path = await ZtLocalStore.pathFor(
        appId: 'phone_tasks',
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
        appId: tasksAppId,
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

  Future<void> _push(ItemSyncEngine engine) async {
    try {
      await engine.sync();
    } on Object {
      // Offline: the next call back pushes it.
    }
  }

  /// Pushes call back tasks (or ticks) saved while offline. Opens the
  /// store only when there's something to send.
  Future<void> flush() async {
    if (ref.read(tasksKeyProvider) == null) return;
    await _withEngine((ItemSyncEngine engine, ZtLocalStore store) async {
      if ((await store.dirtyItems()).isNotEmpty) await _push(engine);
    });
  }

  /// Adds "Call Dana back" due at [due]. Returns the task id.
  Future<String> addCallBack({
    required String title,
    required String number,
    required DateTime due,
    String? contactId,
  }) => _withEngine((ItemSyncEngine engine, ZtLocalStore _) async {
    final Random r = Random.secure();
    final String id = List<String>.generate(
      32,
      (int i) => r.nextInt(16).toRadixString(16),
    ).join();
    await engine.save(
      id,
      callBackTaskJson(
        id: id,
        title: title,
        number: number,
        due: due,
        now: DateTime.now(),
        contactId: contactId,
      ),
    );
    await _push(engine);
    return id;
  });

  /// Ticks the task off (I called back), or deletes it ([delete], when the
  /// reminder is cancelled). Leaves a task already edited away alone.
  Future<void> finish(String taskId, {bool delete = false}) =>
      _withEngine((ItemSyncEngine engine, ZtLocalStore store) async {
        // The latest copy first, so an edit made in ZT Tasks isn't undone.
        await _push(engine);
        final LocalItem? item = await store.get(taskId);
        final Map<String, Object?>? json = item?.json;
        if (item == null || item.deleted || json == null) return;
        if (delete) {
          await engine.delete(taskId);
        } else {
          if (json['isCompleted'] == true) return;
          final String now = DateTime.now().toIso8601String();
          await engine.save(taskId, <String, Object?>{
            ...json,
            'isCompleted': true,
            'completedAt': now,
            'updatedAt': now,
          });
        }
        await _push(engine);
      });
}

final tasksBridgeProvider = Provider<TasksBridge>((ref) => TasksBridge(ref));
