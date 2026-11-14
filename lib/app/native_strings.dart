import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../telecom/telecom.dart';

/// The words Android shows for ZT Phone outside the app (missed call and
/// voicemail notifications, the call notification and channel names), in
/// the language picked in settings. Keys match NativeStrings.kt.
Map<String, String> nativeStrings(AppL10n l) => <String, String>{
  'nativePrivateNumber': l.nativePrivateNumber,
  'nativeMissedCall': l.nativeMissedCall,
  'nativeMissedCalls': l.nativeMissedCalls,
  'nativeLatestFrom': l.nativeLatestFrom,
  'nativeCallBack': l.nativeCallBack,
  'message': l.message,
  'addToContacts': l.addToContacts,
  'nativeNewVoicemail': l.nativeNewVoicemail,
  'nativeVoicemailMessages': l.nativeVoicemailMessages,
  'nativeTapToCallVoicemail': l.nativeTapToCallVoicemail,
  'nativeCallVoicemail': l.nativeCallVoicemail,
  'nativeMissedChannel': l.nativeMissedChannel,
  'voicemail': l.voicemail,
  'nativeIncomingChannel': l.nativeIncomingChannel,
  'nativeOngoingChannel': l.nativeOngoingChannel,
  'incomingCall': l.incomingCall,
  'nativeOngoingCall': l.nativeOngoingCall,
  'onHold': l.onHold,
  'calling': l.calling,
  'nativeHangUp': l.nativeHangUp,
  'nativeCallBackReminder': l.nativeCallBackReminder,
  'nativeCallBackChannel': l.nativeCallBackChannel,
  'nativeRemindMe': l.nativeRemindMe,
};

/// Sends [nativeStrings] to Android whenever the app's language changes.
class NativeStringsSync extends ConsumerStatefulWidget {
  const NativeStringsSync({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<NativeStringsSync> createState() => _NativeStringsSyncState();
}

class _NativeStringsSyncState extends ConsumerState<NativeStringsSync> {
  String? _sent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppL10n l = AppL10n.of(context);
    if (l.localeName == _sent) return;
    _sent = l.localeName;
    ref.read(telecomProvider).setNativeStrings(nativeStrings(l)).ignore();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
