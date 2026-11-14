import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/country_hint.dart';

/// "🇩🇪 Germany · 03:12 there now" for an international [number] (P16),
/// or null when it's a local call or the country isn't known yet.
String? countryHintText(
  BuildContext context,
  WidgetRef ref,
  String number, {
  DateTime? now,
}) {
  final String? home =
      ref.watch(homeCountryProvider).value ??
      WidgetsBinding.instance.platformDispatcher.locale.countryCode;
  final DateTime at = now ?? DateTime.now();
  final CountryHint? hint = CountryHints.forNumber(
    number,
    homeIso: home,
    now: at,
  );
  if (hint == null) return null;
  final AppL10n l = context.l10n;
  final String name = hint.country.name(l.localeName.split('_').first);
  String time(DateTime t) {
    final String hm = TimeOfDay.fromDateTime(t).format(context);
    final int days = DateTime(
      t.year,
      t.month,
      t.day,
    ).difference(DateTime(at.year, at.month, at.day)).inDays;
    return days > 0
        ? l.timeTomorrow(hm)
        : days < 0
        ? l.timeYesterday(hm)
        : hm;
  }

  final DateTime? latest = hint.latest;
  final String when = latest == null
      ? time(hint.earliest)
      : l.timeRange(time(hint.earliest), time(latest));
  return '${hint.country.flag} ${l.countryTimeThere(name, when)}';
}
