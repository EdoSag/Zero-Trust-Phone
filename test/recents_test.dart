import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/pages/call_details_page.dart';
import 'package:zerotrust_phone/pages/favorites_page.dart';
import 'package:zerotrust_phone/pages/recents_page.dart';
import 'package:zerotrust_phone/services/history_backup.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';

CallLogEntry call(int id, String number, CallType type, {String? name}) =>
    CallLogEntry.fromMap(<Object?, Object?>{
      'id': id,
      'number': number,
      'type': switch (type) {
        CallType.incoming => 1,
        CallType.outgoing => 2,
        CallType.missed => 3,
        CallType.blocked => 6,
        _ => 5,
      },
      'date': DateTime(2026, 11, 10, 12, id).millisecondsSinceEpoch,
      'duration': id * 10,
      'cachedName': name,
    });

void main() {
  final ContactDirectory directory = ContactDirectory(const <PhoneContact>[
    PhoneContact(
      id: 'ada',
      name: 'Ada Lovelace',
      phones: <String>['+447700900123'],
      isFavorite: true,
    ),
    PhoneContact(id: 'bob', name: 'Bob', phones: <String>['07700900456']),
  ]);
  final List<CallLogEntry> log = <CallLogEntry>[
    call(1, '07700900123', CallType.missed),
    call(2, '07700900456', CallType.outgoing),
    call(3, '+447700900456', CallType.incoming),
    call(4, '+19005550000', CallType.blocked),
    call(5, '+33123456789', CallType.outgoing, name: 'Café'),
  ];

  test('filters and search', () {
    expect(
      filterCalls(
        log,
        directory,
        filter: RecentsFilter.missed,
      ).map((e) => e.id),
      <int>[1],
    );
    expect(
      filterCalls(
        log,
        directory,
        filter: RecentsFilter.blocked,
      ).map((e) => e.id),
      <int>[4],
    );
    expect(filterCalls(log, directory, query: 'ada').map((e) => e.id), <int>[
      1,
    ]);
    expect(filterCalls(log, directory, query: 'café').map((e) => e.id), <int>[
      5,
    ]);
    expect(filterCalls(log, directory, query: '900456').map((e) => e.id), <int>[
      2,
      3,
    ]);
  });

  test('frequent skips favorites and one-off numbers', () {
    final List<(String, PhoneContact?)> often = FavoritesPage.frequent(
      log,
      directory,
    );
    expect(often.length, 1);
    expect(often.single.$2?.name, 'Bob');
  });

  test('durations', () {
    expect(formatDuration(const Duration(seconds: 12)), '12 sec');
    expect(formatDuration(const Duration(seconds: 65)), '1:05');
    expect(formatDuration(const Duration(seconds: 3723)), '1:02:03');
  });

  test('backup ids are stable and ignore number spelling', () async {
    final DateTime t = DateTime(2026, 11, 10, 12, 0, 5, 300);
    final String a = await HistoryBackup.idFor('+447700900123', t, 1);
    expect(await HistoryBackup.idFor('07700 900123', t, 1), a);
    expect(
      await HistoryBackup.idFor(
        '07700900123',
        t.add(const Duration(milliseconds: 200)),
        1,
      ),
      a,
    );
    expect(await HistoryBackup.idFor('07700900123', t, 2), isNot(a));
    expect(a, startsWith('call_'));
  });
}
