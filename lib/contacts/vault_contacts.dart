import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';

/// The ZT Contacts app id, whose items hold the address book.
const String contactsAppId = 'contacts';

/// The Contacts app key of the unlocked account, derived from the account
/// key at unlock (see AppGate) and zeroed when the vault locks. Phone only
/// ever reads with it.
final contactsKeyProvider = NotifierProvider<ContactsKey, Uint8List?>(
  ContactsKey.new,
);

class ContactsKey extends Notifier<Uint8List?> {
  @override
  Uint8List? build() {
    ref.listen(vaultControllerProvider, (_, VaultState next) {
      if (next is VaultLocked) clear();
    });
    ref.onDispose(_zero);
    return null;
  }

  /// Derives the Contacts key from [dek]. Doesn't take ownership of [dek].
  Future<void> deriveFrom(Uint8List dek) async {
    final Uint8List key = await KeyHierarchy.appKey(dek, contactsAppId);
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

/// Lets the engine pull Contacts items but never upload: Phone has no
/// edits to push, and this makes sure it can't change the address book.
class ReadOnlySyncBackend implements SyncBackend {
  ReadOnlySyncBackend(this.inner);
  final SyncBackend inner;

  @override
  Future<List<RemoteItem>> pull(String app, {DateTime? since}) =>
      inner.pull(app, since: since);

  @override
  Future<List<RemoteItem>> fetch(String app, Set<String> itemIds) =>
      inner.fetch(app, itemIds);

  @override
  Future<Set<String>> pushAll(String app, List<RemoteItem> items) async {
    if (items.isNotEmpty) {
      throw StateError('Phone never writes $app items');
    }
    return <String>{};
  }

  @override
  Future<void> Function() subscribe(
    String app,
    void Function(RemoteItem) onChange,
  ) => inner.subscribe(app, onChange);
}

/// Phone's own encrypted copy of the address book: a local store opened
/// with the Contacts key, kept up to date from the account's Contacts items.
/// Separate from ZT Contacts' own file; deleting it loses nothing.
final contactsMirrorProvider = FutureProvider<ContactsMirror>((ref) async {
  final Uint8List? unlocked = ref.watch(contactsKeyProvider);
  if (unlocked == null) throw const VaultIsLocked();
  final Uint8List key = Uint8List.fromList(unlocked);
  bool disposed = false;
  ref.onDispose(() {
    disposed = true;
    key.fillRange(0, key.length, 0);
  });
  final String? userId = ref.watch(accountServiceProvider).currentUserId;
  if (userId == null) throw StateError('Not signed in');
  final String path = await ZtLocalStore.pathFor(
    appId: 'phone_contacts',
    userId: userId,
  );
  ZtLocalStore store;
  try {
    store = await ZtLocalStore.open(appKey: key, path: path);
  } on LocalStoreUnreadable {
    await ZtLocalStore.moveAside(path);
    store = await ZtLocalStore.open(appKey: key, path: path);
  }
  final String deviceId = await ref.watch(ztDeviceIdProvider.future);
  final ItemSyncEngine engine = await ItemSyncEngine.fromVault(
    appId: contactsAppId,
    appKey: key,
    deviceId: deviceId,
    store: store,
    backend: ReadOnlySyncBackend(ref.watch(ztSyncBackendProvider)),
  );
  final ContactsMirror mirror = ContactsMirror(store: store, engine: engine);
  if (disposed) {
    await mirror.close();
    throw const VaultIsLocked();
  }
  ref.onDispose(mirror.close);
  mirror.start();
  return mirror;
});

class ContactsMirror {
  ContactsMirror({required this.store, required this.engine});

  final ZtLocalStore store;
  final ItemSyncEngine engine;
  AppLifecycleListener? _lifecycle;
  final StreamController<void> _refreshed = StreamController<void>.broadcast();

  /// Pulls now, then follows live changes, and pulls again on resume.
  void start() {
    refresh().ignore();
    engine.startLive();
    _lifecycle = AppLifecycleListener(onResume: () => refresh().ignore());
  }

  Future<void> refresh() async {
    try {
      await engine.sync();
    } on Object {
      // Offline: the names already on this device still work.
    }
    if (!_refreshed.isClosed) _refreshed.add(null);
  }

  Future<List<PhoneContact>> contacts() async {
    final List<PhoneContact> out = <PhoneContact>[
      for (final LocalItem item in await store.liveItems())
        ?PhoneContact.fromItem(item.itemId, item.json),
    ];
    out.sort(
      (PhoneContact a, PhoneContact b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return out;
  }

  Stream<List<PhoneContact>> watch() async* {
    yield await contacts();
    await for (final _ in StreamGroupLite.merge(
      store.changes,
      _refreshed.stream,
    )) {
      yield await contacts();
    }
  }

  Future<void> close() async {
    _lifecycle?.dispose();
    await _refreshed.close();
    await engine.close();
    await store.close();
  }
}

/// Merges two streams without pulling in package:async.
abstract final class StreamGroupLite {
  static Stream<void> merge(Stream<Object?> a, Stream<Object?> b) {
    late final StreamController<void> controller;
    StreamSubscription<Object?>? sa;
    StreamSubscription<Object?>? sb;
    controller = StreamController<void>(
      onListen: () {
        sa = a.listen((_) => controller.add(null));
        sb = b.listen((_) => controller.add(null));
      },
      onCancel: () async {
        await sa?.cancel();
        await sb?.cancel();
      },
    );
    return controller.stream;
  }
}

/// The address book, sorted by name. Empty while locked or before the
/// first pull.
final phoneContactsProvider = StreamProvider<List<PhoneContact>>((ref) async* {
  final ContactsMirror mirror = await ref.watch(contactsMirrorProvider.future);
  yield* mirror.watch();
});

final contactDirectoryProvider = Provider<ContactDirectory>((ref) {
  final List<PhoneContact>? contacts = ref.watch(phoneContactsProvider).value;
  return contacts == null ? ContactDirectory.empty : ContactDirectory(contacts);
});
