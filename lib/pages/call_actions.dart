import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerotrust_phone/app/call_comfort.dart';
import 'package:zerotrust_phone/app/rtt_preference.dart';
import 'package:zerotrust_phone/calendar/meeting_guard.dart';
import 'package:zerotrust_phone/calendar/phone_calendar.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/pages/call_back_sheet.dart';
import 'package:zerotrust_phone/pages/call_details_page.dart';
import 'package:zerotrust_phone/pages/contact_call_settings_page.dart';
import 'package:zerotrust_phone/pages/dial_shortcut_page.dart';
import 'package:zerotrust_phone/pages/dialpad_page.dart';
import 'package:zerotrust_phone/pages/sim_picker.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// Calls [number], on the contact's own SIM when one is set (P6), else
/// the SIM remembered for the number or picked now (P18, [pickSim] always
/// asks), with real-time text when that's switched on (P12). [video] makes
/// it a carrier video call. [hideCallerId] hides my number for this call; a
/// contact set to "Hide my number" always gets it (P22). [number] may end
/// in pauses and tones (P15). False when no call was placed: the SIM
/// picker was closed, or the pocket guard saw a covered screen (P29).
Future<bool> placeCall(
  WidgetRef ref,
  String number, {
  bool video = false,
  bool hideCallerId = false,
  bool pickSim = false,
}) async {
  final CallComfortNotifier comfort = ref.read(callComfortProvider.notifier);
  await comfort.loaded;
  final Telecom telecom = ref.read(telecomProvider);
  if (ref.read(callComfortProvider).pocketGuard &&
      await telecom.screenCovered()) {
    final BuildContext context = ref.context;
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.pocketGuardStopped)),
        );
    }
    return false;
  }
  final PhoneContact? contact = ref
      .read(contactDirectoryProvider)
      .lookup(number);
  String? account;
  bool hide = hideCallerId;
  if (contact != null) {
    for (final ContactCallSettings s
        in ref.read(contactSettingsProvider).value ??
            const <ContactCallSettings>[]) {
      if (s.contactId == contact.id) {
        account = s.accountId;
        hide = hide || s.hideCallerId;
      }
    }
  }
  if (account == null || pickSim) {
    final SimPick pick = await pickSimFor(ref, number, ask: pickSim);
    switch (pick) {
      case SimCancelled():
        return false;
      case SimChosen(:final String? accountId):
        account = accountId ?? account;
    }
  }
  final StartWithRtt rtt = ref.read(startWithRttProvider.notifier);
  await rtt.loaded;
  // Without the camera the call still goes out, showing only their video.
  if (video) await telecom.requestCamera();
  await telecom.placeCall(
    number,
    account: account,
    rtt: ref.read(startWithRttProvider),
    video: video,
    hideCallerId: hide,
  );
  return true;
}

Future<void> sendMessage(String number) =>
    launchUrl(Uri(scheme: 'smsto', path: number));

/// A contact or number: call, copy, edit before calling, block.
Future<void> showNumberSheet(
  BuildContext context,
  WidgetRef ref, {
  required String number,
  PhoneContact? contact,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (BuildContext sheet) {
    final String title = contact?.name ?? number;
    final List<String> numbers = contact != null && contact.phones.isNotEmpty
        ? contact.phones
        : <String>[number];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          ListTile(
            leading: ContactAvatar(label: contact?.name ?? '', radius: 24),
            title: Text(title, style: Theme.of(sheet).textTheme.titleLarge),
            subtitle: contact != null && contact.company.isNotEmpty
                ? Text(contact.company)
                : null,
          ),
          // P26: the next meeting with them in ZT Calendar.
          if (contact != null) MeetingLine(contact: contact),
          const Divider(),
          for (final String n in numbers)
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: Text(ltr(n)),
              subtitle: Text(context.l10n.call),
              onTap: () {
                Navigator.of(sheet).pop();
                placeCall(ref, n);
              },
              // P12: only when the carrier offers video calls.
              trailing: Consumer(
                builder: (BuildContext _, WidgetRef inner, Widget? _) =>
                    inner.watch(callFeaturesProvider).value?.video ?? false
                    ? IconButton(
                        tooltip: context.l10n.videoCall,
                        icon: const Icon(Icons.videocam_outlined),
                        onPressed: () {
                          Navigator.of(sheet).pop();
                          placeCall(ref, n, video: true);
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          // P15: saved "dial with pauses" shortcuts, one tap each.
          DialShortcutTiles(
            numbers: numbers,
            contact: contact,
            onBeforeCall: () => Navigator.of(sheet).pop(),
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: Text(context.l10n.callWithNumberHidden),
            subtitle: Text(context.l10n.callWithNumberHiddenBody),
            onTap: () {
              Navigator.of(sheet).pop();
              placeCall(ref, number, hideCallerId: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.more_time),
            title: Text(context.l10n.dialWithPauses),
            subtitle: Text(context.l10n.dialWithPausesShort),
            onTap: () {
              Navigator.of(sheet).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      DialShortcutPage(number: number, contact: contact),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.alarm_add_outlined),
            title: Text(context.l10n.remindMeToCallBackShort),
            subtitle: Text(context.l10n.remindMeToCallBackBody),
            onTap: () {
              Navigator.of(sheet).pop();
              showCallBackSheet(context, ref, number: number, contact: contact);
            },
          ),
          ListTile(
            leading: const Icon(Icons.message_outlined),
            title: Text(context.l10n.sendAMessage),
            onTap: () {
              Navigator.of(sheet).pop();
              sendMessage(number);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(context.l10n.callHistory),
            onTap: () {
              Navigator.of(sheet).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CallDetailsPage(number: number),
                ),
              );
            },
          ),
          if (contact != null)
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(context.l10n.ringtoneVoicemailSim),
              onTap: () {
                Navigator.of(sheet).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ContactCallSettingsPage(contact: contact),
                  ),
                );
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.person_add_alt_outlined),
              title: Text(context.l10n.addToContacts),
              onTap: () {
                Navigator.of(sheet).pop();
                ref.read(telecomProvider).addContact(number);
              },
            ),
          ListTile(
            leading: const Icon(Icons.dialpad),
            title: Text(context.l10n.editBeforeCalling),
            onTap: () {
              Navigator.of(sheet).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DialpadPage(initialNumber: number),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: Text(context.l10n.copyNumber),
            onTap: () {
              Clipboard.setData(ClipboardData(text: number));
              Navigator.of(sheet).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: Text(context.l10n.blockNumber),
            subtitle: Text(context.l10n.blockNumberBody),
            onTap: () async {
              Navigator.of(sheet).pop();
              await confirmBlock(context, ref, number);
            },
          ),
        ],
      ),
    );
  },
);

Future<void> confirmBlock(
  BuildContext context,
  WidgetRef ref,
  String number,
) async {
  final Telecom telecom = ref.read(telecomProvider);
  if (!await telecom.canBlock()) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.setAsPhoneToBlock)));
    }
    return;
  }
  if (!context.mounted) return;
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext d) => AlertDialog(
      title: Text(d.l10n.blockNumberQuestion(ltr(number))),
      content: Text(d.l10n.blockNumberExplain),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(d).pop(false),
          child: Text(d.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(d).pop(true),
          child: Text(d.l10n.block),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await telecom.block(number);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.numberBlocked(ltr(number)))),
    );
  }
}

/// "Tomorrow 10:00: Design review": the next meeting with [contact] in ZT
/// Calendar (P26), or nothing.
class MeetingLine extends ConsumerWidget {
  const MeetingLine({super.key, required this.contact});
  final PhoneContact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(meetingGuardProvider).showMeetings) {
      return const SizedBox.shrink();
    }
    final List<PhoneEvent> events =
        ref.watch(phoneEventsProvider).value ?? const <PhoneEvent>[];
    final DateTime now = DateTime.now();
    final Meeting? m = Meetings.nextWith(events, contact, now);
    if (m == null) return const SizedBox.shrink();
    final AppL10n l = context.l10n;
    return ListTile(
      key: const ValueKey<String>('meeting-line'),
      dense: true,
      leading: Icon(
        Icons.event_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(meetingLine(m, now, l, l.localeName)),
    );
  }
}
