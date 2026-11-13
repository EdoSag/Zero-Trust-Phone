import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/call_actions.dart';
import 'package:zerotrust_phone/services/call_backs.dart';

/// "Remind me to call back" (P25): in 15 minutes, an hour, 3 hours,
/// tonight, tomorrow morning, or a time I pick.
Future<void> showCallBackSheet(
  BuildContext context,
  WidgetRef ref, {
  required String number,
  PhoneContact? contact,
  DateTime? now,
}) async {
  final PhoneContact? who =
      contact ?? ref.read(contactDirectoryProvider).lookup(number);
  final DateTime from = now ?? DateTime.now();
  final DateTime? at = await showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheet) {
      final AppL10n l = sheet.l10n;
      String label(CallBackWhen w) => switch (w) {
        CallBackWhen.in15m => l.in15Minutes,
        CallBackWhen.in1h => l.in1Hour,
        CallBackWhen.in3h => l.in3Hours,
        CallBackWhen.tonight => l.tonight,
        CallBackWhen.tomorrow => l.tomorrowMorning,
      };
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l.remindMeToCallBack(who?.name ?? ltr(number)),
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            for (final CallBackWhen w in CallBackWhen.values)
              ListTile(
                leading: const Icon(Icons.alarm),
                title: Text(label(w)),
                trailing: Text(
                  TimeOfDay.fromDateTime(callBackTime(w, from)).format(sheet),
                ),
                onTap: () => Navigator.of(sheet).pop(callBackTime(w, from)),
              ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: Text(l.pickATime),
              onTap: () async {
                final DateTime? day = await showDatePicker(
                  context: sheet,
                  firstDate: DateTime(from.year, from.month, from.day),
                  lastDate: from.add(const Duration(days: 365)),
                  initialDate: from,
                );
                if (day == null || !sheet.mounted) return;
                final TimeOfDay? time = await showTimePicker(
                  context: sheet,
                  initialTime: TimeOfDay.fromDateTime(
                    from.add(const Duration(hours: 1)),
                  ),
                );
                if (time == null || !sheet.mounted) return;
                Navigator.of(sheet).pop(
                  DateTime(
                    day.year,
                    day.month,
                    day.day,
                    time.hour,
                    time.minute,
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Text(
                l.callBackExplain,
                style: Theme.of(sheet).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    },
  );
  if (at == null || !context.mounted) return;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final AppL10n l = context.l10n;
  final String time = TimeOfDay.fromDateTime(at).format(context);
  final bool inTasks = await ref
      .read(callBacksServiceProvider)
      .add(number: number, at: at, contact: who);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          inTasks ? l.callBackSetWithTask(time) : l.callBackSetNoTask(time),
        ),
      ),
    );
}

/// Pending call back reminders, at the top of Recents.
class CallBackList extends ConsumerWidget {
  const CallBackList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<CallBack> all =
        ref.watch(callBacksProvider).value ?? const <CallBack>[];
    if (all.isEmpty) return const SizedBox.shrink();
    final List<CallBack> sorted = <CallBack>[...all]
      ..sort((CallBack a, CallBack b) => a.at.compareTo(b.at));
    final AppL10n l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final CallBack c in sorted)
          ListTile(
            key: ValueKey<String>('call-back-${c.id}'),
            leading: Icon(
              Icons.alarm,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              l.callBackName(
                ref.watch(contactDirectoryProvider).lookup(c.number)?.name ??
                    (c.name.isNotEmpty ? c.name : ltr(c.number)),
              ),
            ),
            subtitle: Text(_when(context, c.at)),
            onTap: () => placeCall(ref, c.number),
            trailing: IconButton(
              tooltip: l.cancelReminder,
              icon: const Icon(Icons.close),
              onPressed: () => ref.read(callBacksServiceProvider).cancel(c),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  static String _when(BuildContext context, DateTime at) {
    final String time = TimeOfDay.fromDateTime(at).format(context);
    final DateTime now = DateTime.now();
    final int days = DateTime(
      at.year,
      at.month,
      at.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (at.isBefore(now)) return context.l10n.callBackDue(time);
    return days == 0 ? time : context.l10n.timeTomorrow(time);
  }
}
