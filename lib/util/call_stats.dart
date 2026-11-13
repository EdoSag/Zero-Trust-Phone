import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';

/// Call stats (P28), worked out on the phone from the call history: nothing
/// is sent anywhere.
enum StatsPeriod {
  week(7),
  month(30),
  year(365),
  all(null);

  const StatsPeriod(this.days);
  final int? days;
}

/// One person (a contact, or a number not in Contacts).
class PersonStats {
  PersonStats({required this.number, this.contact});

  final String number;
  final PhoneContact? contact;
  int calls = 0;
  int missed = 0;
  Duration talk = Duration.zero;
  DateTime? last;
}

/// One week's calls, from [start] (the first day of the week).
class WeekStats {
  WeekStats(this.start);
  final DateTime start;
  int calls = 0;
  Duration talk = Duration.zero;
}

class CallStats {
  CallStats._();

  int calls = 0;
  int incoming = 0;
  int outgoing = 0;
  int missed = 0;
  Duration talk = Duration.zero;

  /// Calls that connected (some talk time), for the average.
  int answered = 0;

  /// The last [weekCount] weeks, oldest first.
  final List<WeekStats> weeks = <WeekStats>[];

  /// Most talked-to first, then most calls.
  final List<PersonStats> people = <PersonStats>[];

  Duration get averageCall => answered == 0
      ? Duration.zero
      : Duration(seconds: (talk.inSeconds / answered).round());

  static const int weekCount = 8;

  /// Stats for [period] up to [now]. Weeks start on [firstDayOfWeek]
  /// (DateTime.sunday in Israel, DateTime.monday in much of Europe) and
  /// always cover the last [weekCount] weeks.
  static CallStats compute(
    List<CallLogEntry> log, {
    required DateTime now,
    required StatsPeriod period,
    ContactDirectory? directory,
    int firstDayOfWeek = DateTime.sunday,
  }) {
    final CallStats s = CallStats._();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int back = (today.weekday - firstDayOfWeek) % 7;
    final DateTime thisWeek = DateTime(
      today.year,
      today.month,
      today.day - back,
    );
    for (int i = weekCount - 1; i >= 0; i--) {
      s.weeks.add(
        WeekStats(
          DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * i),
        ),
      );
    }
    final int? days = period.days;
    final DateTime? from = days == null
        ? null
        : DateTime(today.year, today.month, today.day - days + 1);
    final Map<String, PersonStats> byPerson = <String, PersonStats>{};

    for (final CallLogEntry e in log) {
      if (e.date.isAfter(now)) continue;
      final bool talked = e.duration > Duration.zero;
      // Weeks.
      for (final WeekStats w in s.weeks.reversed) {
        if (!e.date.isBefore(w.start)) {
          if (e.date.isBefore(
            DateTime(w.start.year, w.start.month, w.start.day + 7),
          )) {
            w.calls++;
            w.talk += e.duration;
          }
          break;
        }
      }
      if (from != null && e.date.isBefore(from)) continue;
      s.calls++;
      s.talk += e.duration;
      if (talked) s.answered++;
      switch (e.type) {
        case CallType.incoming:
          s.incoming++;
        case CallType.outgoing:
          s.outgoing++;
        case CallType.missed:
          s.missed++;
        default:
          break;
      }
      if (e.number.trim().isEmpty) continue;
      final PhoneContact? contact = directory?.lookup(e.number);
      final String key = contact != null
          ? 'c:${contact.id}'
          : 'n:${PhoneNumbers.lookupKey(e.number)}';
      final PersonStats p = byPerson.putIfAbsent(
        key,
        () => PersonStats(number: e.number, contact: contact),
      );
      p.calls++;
      p.talk += e.duration;
      if (e.type == CallType.missed) p.missed++;
      final DateTime? last = p.last;
      if (last == null || e.date.isAfter(last)) p.last = e.date;
    }
    s.people.addAll(byPerson.values);
    s.people.sort((PersonStats a, PersonStats b) {
      final int t = b.talk.compareTo(a.talk);
      return t != 0 ? t : b.calls.compareTo(a.calls);
    });
    return s;
  }
}
