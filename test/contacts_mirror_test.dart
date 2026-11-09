import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';

import 'support/fake_sync_backend.dart';

void main() {
  final Uint8List dek = Uint8List.fromList(List<int>.generate(32, (i) => i));

  test(
    'Phone reads what ZT Contacts wrote, with the same account key',
    () async {
      final FakeSyncBackend server = FakeSyncBackend();

      // ZT Contacts on another device saves a contact.
      final ItemSyncEngine contactsApp = await ItemSyncEngine.fromVault(
        appId: 'contacts',
        appKey: await KeyHierarchy.appKey(dek, 'contacts'),
        deviceId: 'contacts-device',
        store: InMemoryItemStore(),
        backend: server,
      );
      await contactsApp.save('c1', <String, Object?>{
        'kind': 'contact',
        '_v': 1,
        'displayName': 'Ada Lovelace',
        'phones': <String>['+44 7700 900123'],
        'isFavorite': true,
      });
      await contactsApp.sync();

      // Phone derives the Contacts key from the same account key and pulls.
      final InMemoryItemStore mirror = InMemoryItemStore();
      final ItemSyncEngine phone = await ItemSyncEngine.fromVault(
        appId: contactsAppId,
        appKey: await KeyHierarchy.appKey(dek, contactsAppId),
        deviceId: 'phone-device',
        store: mirror,
        backend: ReadOnlySyncBackend(server),
      );
      final SyncResult result = await phone.sync();
      expect(result.rejected, isEmpty);

      final List<PhoneContact> contacts = <PhoneContact>[
        for (final LocalItem item in await mirror.all())
          ?PhoneContact.fromItem(item.itemId, item.json),
      ];
      expect(contacts.single.name, 'Ada Lovelace');
      expect(contacts.single.isFavorite, isTrue);
    },
  );

  test('Phone can never upload Contacts items', () async {
    final FakeSyncBackend server = FakeSyncBackend();
    final ItemSyncEngine phone = await ItemSyncEngine.fromVault(
      appId: contactsAppId,
      appKey: await KeyHierarchy.appKey(dek, contactsAppId),
      deviceId: 'phone-device',
      store: InMemoryItemStore(),
      backend: ReadOnlySyncBackend(server),
    );
    await phone.save('x', <String, Object?>{'kind': 'contact'});
    await expectLater(phone.sync(), throwsStateError);
    expect(server.rows, isEmpty);
  });

  test('a key for another app cannot read Contacts items', () async {
    final FakeSyncBackend server = FakeSyncBackend();
    final ItemSyncEngine contactsApp = await ItemSyncEngine.fromVault(
      appId: 'contacts',
      appKey: await KeyHierarchy.appKey(dek, 'contacts'),
      deviceId: 'contacts-device',
      store: InMemoryItemStore(),
      backend: server,
    );
    await contactsApp.save('c1', <String, Object?>{'kind': 'contact'});
    await contactsApp.sync();

    final InMemoryItemStore mirror = InMemoryItemStore();
    final ItemSyncEngine wrongKey = await ItemSyncEngine.fromVault(
      appId: contactsAppId,
      appKey: await KeyHierarchy.appKey(dek, 'phone'),
      deviceId: 'phone-device',
      store: mirror,
      backend: ReadOnlySyncBackend(server),
    );
    final SyncResult result = await wrongKey.sync();
    expect(result.rejected, <String>['c1']);
    expect(await mirror.all(), isEmpty);
  });
}
