// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get block => 'Block';

  @override
  String get call => 'Call';

  @override
  String get privateNumber => 'Private number';

  @override
  String get voicemail => 'Voicemail';

  @override
  String callName(String name) {
    return 'Call $name';
  }

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get retentionForever => 'Forever';

  @override
  String get retention24h => '24 hours';

  @override
  String retentionDays(int days) {
    return '$days days';
  }

  @override
  String get dialpadNoUnlock => 'Dialpad, no unlock needed';

  @override
  String get conferenceCall => 'Conference call';

  @override
  String get callEnded => 'Call ended';

  @override
  String get hide => 'Hide';

  @override
  String get endCall => 'End call';

  @override
  String get declineWithMessage => 'Decline and send a message';

  @override
  String get writeYourOwn => 'Write your own…';

  @override
  String get send => 'Send';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get carAudio => 'Car audio';

  @override
  String get phoneAudio => 'Phone audio';

  @override
  String get speaker => 'Speaker';

  @override
  String get incomingCall => 'Incoming call';

  @override
  String get chooseSim => 'Choose a SIM';

  @override
  String get calling => 'Calling…';

  @override
  String get onHold => 'On hold';

  @override
  String get connected => 'Connected';

  @override
  String callWithAccount(String account) {
    return 'Call with $account';
  }

  @override
  String get decline => 'Decline';

  @override
  String get endAndAnswer => 'End & answer';

  @override
  String get holdAndAnswer => 'Hold & answer';

  @override
  String get answer => 'Answer';

  @override
  String get replyWithMessage => 'Reply with a message';

  @override
  String get keypad => 'Keypad';

  @override
  String get audio => 'Audio';

  @override
  String get resume => 'Resume';

  @override
  String get hold => 'Hold';

  @override
  String get merge => 'Merge';

  @override
  String get addCall => 'Add call';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get headset => 'Headset';

  @override
  String get phoneEarpiece => 'Phone';

  @override
  String get swap => 'Swap';

  @override
  String get defaultPhoneApp => 'Default Phone app';

  @override
  String get defaultPhoneAppOn => 'ZT Phone handles your calls';

  @override
  String get defaultPhoneAppOff =>
      'Another app handles calls. Tap to switch to ZT Phone';

  @override
  String get namesFromContacts => 'Names from ZT Contacts';

  @override
  String namesFromContactsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count contacts, encrypted on this phone. Edit them in ZT Contacts',
      one: '1 contact, encrypted on this phone. Edit them in ZT Contacts',
    );
    return '$_temp0';
  }

  @override
  String get keepCallHistory => 'Keep call history';

  @override
  String get callProtection => 'Call protection';

  @override
  String get blockedNumbers => 'Blocked numbers';

  @override
  String get quickReplies => 'Quick replies';

  @override
  String get quickRepliesBody => 'Texts to send when you decline a call';

  @override
  String get speedDial => 'Speed dial';

  @override
  String get speedDialBody => 'Hold 2 to 9 on the dialpad';

  @override
  String get voicemailBody =>
      'Hold 1 on the dialpad to call it. Tap for your carrier\'s voicemail settings';

  @override
  String get callHistoryBackup => 'Call history backup';

  @override
  String get backupOn => 'On, end-to-end encrypted';

  @override
  String get off => 'Off';

  @override
  String get dndStarred => 'Do Not Disturb and starred contacts';

  @override
  String get dndStarredBody =>
      'Android lets starred contacts through Do Not Disturb only if it can see them. Turn on \"Show in Phone and Messages\" in ZT Contacts settings for that.';

  @override
  String get unknownSilenced => 'Unknown callers silenced';

  @override
  String get unknownToVoicemail => 'Unknown callers to voicemail';

  @override
  String get hiddenBlocked => 'hidden numbers blocked';

  @override
  String prefixesBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocked prefixes',
      one: '1 blocked prefix',
    );
    return '$_temp0';
  }

  @override
  String get protectionOff =>
      'Off. Silence unknown callers, block hidden numbers or prefixes';

  @override
  String get retentionBody =>
      'Older calls are deleted from this phone\'s call history, also for other apps.';

  @override
  String get addANumber => 'Add a number';

  @override
  String get noBlockedNumbers =>
      'No blocked numbers.\nBlock a number from Recents or from here.';

  @override
  String get unblock => 'Unblock';

  @override
  String get blockANumber => 'Block a number';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get next => 'Next';

  @override
  String get sendAMessage => 'Send a message';

  @override
  String get callHistory => 'Call history';

  @override
  String get ringtoneVoicemailSim => 'Ringtone, voicemail and SIM';

  @override
  String get addToContacts => 'Add to contacts';

  @override
  String get editBeforeCalling => 'Edit number before calling';

  @override
  String get copyNumber => 'Copy number';

  @override
  String get blockNumber => 'Block number';

  @override
  String get blockNumberBody => 'Calls from it are silently declined';

  @override
  String get setAsPhoneToBlock =>
      'Set ZT Phone as your Phone app to block numbers';

  @override
  String blockNumberQuestion(String number) {
    return 'Block $number?';
  }

  @override
  String get blockNumberExplain =>
      'You won\'t get calls or texts from this number. Android keeps the list, so it also applies in other phone and messaging apps.';

  @override
  String numberBlocked(String number) {
    return '$number blocked';
  }

  @override
  String get reset => 'Reset';

  @override
  String get add => 'Add';

  @override
  String get quickRepliesExplain =>
      'Offered when a call comes in. The text goes out through your messaging app, from your number.';

  @override
  String get newReply => 'New reply';

  @override
  String get editReply => 'Edit reply';

  @override
  String get unlockToChangeSpeedDial => 'Unlock ZT Phone to change speed dial';

  @override
  String get hold1 => 'Hold 1 on the dialpad';

  @override
  String get notSet => 'Not set';

  @override
  String get remove => 'Remove';

  @override
  String get speedDialExplain =>
      'Hold a number on the dialpad to call. Saved encrypted in your account.';

  @override
  String speedDialSearch(int digit) {
    return 'Speed dial $digit: search contacts';
  }

  @override
  String get noContactsWithNumber => 'No contacts with a phone number';

  @override
  String get backUpCallHistory => 'Back up call history';

  @override
  String get backUpCallHistoryBody =>
      'End-to-end encrypted in your account, so a new phone can get it back. Only you can read it.';

  @override
  String backedUpCalls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Backed up $count calls',
      one: 'Backed up 1 call',
    );
    return '$_temp0';
  }

  @override
  String get backupDeleted => 'Backup turned off and deleted';

  @override
  String get backUpNow => 'Back up now';

  @override
  String get alreadyUpToDate => 'Already up to date';

  @override
  String get restoreToPhone => 'Restore to this phone';

  @override
  String get restoreToPhoneBody =>
      'Adds backed-up calls missing from this phone\'s history';

  @override
  String get nothingToRestore => 'Nothing to restore';

  @override
  String restoredCalls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restored $count calls',
      one: 'Restored 1 call',
    );
    return '$_temp0';
  }

  @override
  String get backupExplain =>
      'The backup follows \"Keep call history\": older calls are removed from it too. Deleting a call in Recents also deletes its backup.';

  @override
  String get unknownCallersHeader => 'Calls from numbers not in your contacts';

  @override
  String get blockHidden => 'Block hidden numbers';

  @override
  String get blockHiddenBody => 'Private and unknown caller IDs';

  @override
  String get blockedPrefixes => 'Blocked prefixes and countries';

  @override
  String get blockedPrefixesBody =>
      'Block every number that starts with, for example, +1900 or a whole country such as +44';

  @override
  String get addPrefix => 'Add prefix';

  @override
  String removePrefix(String prefix) {
    return 'Remove $prefix';
  }

  @override
  String get protectionExplain =>
      'Contacts you block or send to voicemail in ZT Contacts are handled here too. Rules work while ZT Phone is locked, and your contacts always ring unless you send them to voicemail.';

  @override
  String get blockStartingWith => 'Block numbers starting with';

  @override
  String get unknownRing => 'Ring as usual';

  @override
  String get unknownSilence => 'Silence (they still show in Recents)';

  @override
  String get unknownVoicemail => 'Send to voicemail';

  @override
  String couldntOpenContacts(String reason) {
    return 'Couldn\'t open your contacts. $reason';
  }

  @override
  String noContactsMatch(String query) {
    return 'No contacts match \"$query\"';
  }

  @override
  String get noFavoritesContacts =>
      'No favorites yet.\nStar contacts in ZT Contacts and they show up here.';

  @override
  String get contactsComeFrom =>
      'Your contacts come from ZT Contacts, end-to-end encrypted with the same account. Add some there and they show up here.';

  @override
  String get getZtContacts => 'Get ZT Contacts';

  @override
  String get deleteThisHistory => 'Delete this history';

  @override
  String get message => 'Message';

  @override
  String get callSettings => 'Call settings';

  @override
  String get noCallsInHistory => 'No calls in this phone\'s history.';

  @override
  String dayAndTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String deleteCallsQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count calls from history?',
      one: 'Delete 1 call from history?',
    );
    return '$_temp0';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds sec';
  }

  @override
  String get incoming => 'Incoming';

  @override
  String get outgoing => 'Outgoing';

  @override
  String get missed => 'Missed';

  @override
  String get declined => 'Declined';

  @override
  String get blocked => 'Blocked';

  @override
  String get noFavoritesFrequent =>
      'No favorites yet.\nStar contacts in ZT Contacts and they show up here, with the people you call most.';

  @override
  String get frequent => 'Frequent';

  @override
  String get searchCalls => 'Search calls';

  @override
  String get searchContacts => 'Search contacts';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get settings => 'Settings';

  @override
  String get dialpad => 'Dialpad';

  @override
  String get favorites => 'Favorites';

  @override
  String get recents => 'Recents';

  @override
  String get contacts => 'Contacts';

  @override
  String get callAlertsOff =>
      'Incoming calls can\'t show on the lock screen or as a notification. Allow call notifications for ZT Phone.';

  @override
  String get allow => 'Allow';

  @override
  String get makeDefault =>
      'Make ZT Phone your Phone app to answer calls here, see your call history and block numbers.';

  @override
  String get setAsDefault => 'Set as default';

  @override
  String get ringtone => 'Ringtone';

  @override
  String get phoneRingtone => 'The phone\'s ringtone';

  @override
  String get custom => 'Custom';

  @override
  String get sendToVoicemail => 'Send calls to voicemail';

  @override
  String get sendToVoicemailBody =>
      'Their calls don\'t ring; they can leave a message';

  @override
  String get callWith => 'Call with';

  @override
  String get askOrDefault => 'Ask or use the default';

  @override
  String get callSettingsExplain =>
      'Saved encrypted in your account, so a new phone gets them too. They work while ZT Phone is locked; the phone keeps only a scrambled form of the numbers for that.';

  @override
  String get filterAll => 'All';

  @override
  String couldntReadHistory(String reason) {
    return 'Couldn\'t read your call history.\n$reason';
  }

  @override
  String noCallsMatch(String query) {
    return 'No calls match \"$query\"';
  }

  @override
  String get noCallsYet =>
      'No calls yet.\nCalls you make and get show up here.';

  @override
  String get noMissedCalls => 'No missed calls';

  @override
  String get noIncomingCalls => 'No incoming calls';

  @override
  String get noOutgoingCalls => 'No outgoing calls';

  @override
  String get noBlockedCalls => 'No blocked calls';

  @override
  String get deleteThisCall => 'Delete this call from history?';

  @override
  String noSpeedDialOn(String digit) {
    return 'No speed dial on $digit';
  }

  @override
  String get pickContactForKey =>
      'Pick a contact to call when you hold this key.';

  @override
  String get pickContact => 'Pick contact';

  @override
  String get keyZeroHold => '0, hold for plus';

  @override
  String get keyOneHold => '1, hold for voicemail';

  @override
  String get nativePrivateNumber => 'Private number';

  @override
  String get nativeMissedCall => 'Missed call';

  @override
  String get nativeMissedCalls => '%d missed calls';

  @override
  String get nativeLatestFrom => 'Latest from %s';

  @override
  String get nativeCallBack => 'Call back';

  @override
  String get nativeNewVoicemail => 'New voicemail';

  @override
  String get nativeVoicemailMessages => '%d messages. Tap to call voicemail';

  @override
  String get nativeTapToCallVoicemail => 'Tap to call voicemail';

  @override
  String get nativeCallVoicemail => 'Call voicemail';

  @override
  String get nativeMissedChannel => 'Missed calls';

  @override
  String get nativeIncomingChannel => 'Incoming calls';

  @override
  String get nativeOngoingChannel => 'Ongoing calls';

  @override
  String get nativeOngoingCall => 'Ongoing call';

  @override
  String get nativeHangUp => 'Hang up';

  @override
  String get replyCantTalk => 'Can\'t talk now. I\'ll call you back.';

  @override
  String get replyDriving => 'I\'m driving. I\'ll call you soon.';

  @override
  String get replyMeeting => 'In a meeting. Can you text me?';

  @override
  String get replyOnMyWay => 'On my way.';

  @override
  String get accept => 'Accept';

  @override
  String get rtt => 'RTT';

  @override
  String get video => 'Video';

  @override
  String get videoCall => 'Video call';

  @override
  String get incomingVideoCall => 'Incoming video call';

  @override
  String get answerVoice => 'Voice';

  @override
  String get answerVideo => 'Video';

  @override
  String get rttRequestBody => 'They want to switch to real-time text (RTT).';

  @override
  String get videoRequestBody => 'They want to switch to video.';

  @override
  String get rttFailed => 'Real-time text isn\'t available on this call.';

  @override
  String get videoFailed =>
      'Video couldn\'t start. Your carrier may not allow it on this call.';

  @override
  String get rttHint =>
      'Type to talk. They see each letter as you type it, and their words appear here as they type.';

  @override
  String get rttTypeHere => 'Type a message';

  @override
  String get rttSeesTyping => 'Sent as you type';

  @override
  String get rttYouSaid => 'You';

  @override
  String get rttTheySaid => 'Them';

  @override
  String get waitingForVideo => 'Waiting for video';

  @override
  String get cameraOff => 'Camera off';

  @override
  String get cameraOn => 'Camera on';

  @override
  String get switchCamera => 'Flip';

  @override
  String get voiceOnly => 'Voice only';

  @override
  String get callAccessibility => 'Accessibility and video';

  @override
  String get callAccessibilityBody =>
      'Real-time text (RTT), TTY and video calls';

  @override
  String get startWithRtt => 'Start calls with real-time text';

  @override
  String get startWithRttBody =>
      'Type and read during calls, with or instead of talking. The other person sees each letter as you type. You can also turn on RTT during any call that supports it.';

  @override
  String get rttAvailable => 'Your carrier offers RTT on this phone';

  @override
  String get rttNotAvailable => 'RTT isn\'t offered on this phone right now';

  @override
  String get rttNotAvailableBody =>
      'RTT needs your carrier\'s support. On many phones it also needs RTT switched on in Android\'s accessibility settings, under TTY and RTT below.';

  @override
  String get videoCalling => 'Carrier video calls';

  @override
  String get videoAvailable =>
      'Available. Look for the video button when you call, or turn video on during a call.';

  @override
  String get videoNotAvailable =>
      'Not offered right now. Video calls need your carrier\'s VoLTE and video calling, which you may need to turn on in Android\'s SIM settings.';

  @override
  String get ttySettings => 'TTY mode and RTT settings';

  @override
  String get ttySettingsBody =>
      'Opens your phone\'s built-in call accessibility settings. Android lets only the built-in Phone app change TTY mode.';

  @override
  String get ttySettingsMissing =>
      'This phone has no built-in screen for TTY mode, and Android doesn\'t let other apps change it.';

  @override
  String get callAccessibilityPrivacy =>
      'Real-time text and video go over your carrier\'s network, straight to the other person. ZT Phone never sends them to its servers or keeps them after the call.';

  @override
  String get pasteNumber => 'Paste a number';

  @override
  String get noNumberInText => 'No phone number found in the copied text';

  @override
  String get whichNumber => 'Which number?';

  @override
  String get dialWithPauses => 'Dial with pauses';

  @override
  String get dialWithPausesShort => 'Wait, then send a code or menu choice';

  @override
  String get dialWithPausesExplain =>
      'For phone menus, conference codes and voicemail PINs: call, wait, then send the digits for you. Save it and it\'s one tap next time.';

  @override
  String get dialShortcutDefaultLabel => 'Call with code';

  @override
  String get dialShortcutName => 'Name';

  @override
  String get dialShortcutNameHint => 'Voicemail PIN, Work conference…';

  @override
  String get numberToCall => 'Number to call';

  @override
  String get addPause => 'Wait 3 seconds';

  @override
  String get addWaitForTap => 'Wait for my tap';

  @override
  String get addTones => 'Send digits';

  @override
  String get dialsAs => 'Dials';

  @override
  String get callNow => 'Call now';

  @override
  String pauseSeconds(int seconds) {
    return 'Wait about $seconds seconds';
  }

  @override
  String get shorterPause => 'Shorter';

  @override
  String get longerPause => 'Longer';

  @override
  String get waitForTapStep => 'Wait until I tap Send on the call screen';

  @override
  String get tonesToSend => 'Digits to send';

  @override
  String get removeStep => 'Remove step';

  @override
  String get edit => 'Edit';

  @override
  String get hideMyNumber => 'Hide my number on this call';

  @override
  String get showMyNumber => 'Show my number on this call';

  @override
  String get numberHidden => 'My number hidden';

  @override
  String get keyStarHold => 'Star, hold for a pause';

  @override
  String get keyHashHold => 'Hash, hold for wait';

  @override
  String get callWithNumberHidden => 'Call with my number hidden';

  @override
  String get callWithNumberHiddenBody =>
      'They see \"Private number\", if your carrier allows it. Emergency numbers always see your number.';

  @override
  String get hideMyNumberForContact => 'Hide my number';

  @override
  String get hideMyNumberForContactBody =>
      'Every call to this contact shows \"Private number\", if your carrier allows it. Emergency numbers always see your number.';

  @override
  String timeTomorrow(String time) {
    return '$time tomorrow';
  }

  @override
  String timeYesterday(String time) {
    return '$time yesterday';
  }

  @override
  String timeRange(String from, String to) {
    return '$from–$to';
  }

  @override
  String countryTimeThere(String country, String time) {
    return '$country · $time there now';
  }

  @override
  String sendTonesQuestion(String tones) {
    return 'Send $tones now?';
  }

  @override
  String get skip => 'Skip';

  @override
  String get privateCallLog => 'Private call log';

  @override
  String get privateCallLogBody =>
      'Calls with this contact are kept only in your encrypted vault, not in Android\'s shared call history that other apps can read. Your carrier still keeps its own record.';

  @override
  String movedToVault(int count) {
    return 'Moved $count past calls into the vault';
  }

  @override
  String get callStats => 'Call stats';

  @override
  String get statsWeek => '7 days';

  @override
  String get statsMonth => '30 days';

  @override
  String get statsYear => 'Year';

  @override
  String get statsCalls => 'Calls';

  @override
  String statsInOut(int incoming, int outgoing) {
    return '$incoming in · $outgoing out';
  }

  @override
  String get statsTalkTime => 'Talk time';

  @override
  String get statsAverageCall => 'Average call';

  @override
  String get statsLastWeeks => 'Last 8 weeks';

  @override
  String get statsMostTalked => 'Who you talk to most';

  @override
  String statsPersonLine(int calls, String talk) {
    return '$calls calls · $talk';
  }

  @override
  String statsWeekBar(String start, int calls, String talk) {
    return 'Week of $start: $calls calls, $talk';
  }

  @override
  String get statsPrivacy =>
      'Worked out on this phone from your call history. Nothing is sent anywhere.';

  @override
  String talkMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String talkHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String remindMeToCallBack(String name) {
    return 'Remind me to call $name back';
  }

  @override
  String get remindMeToCallBackShort => 'Remind me to call back';

  @override
  String get remindMeToCallBackBody =>
      'A reminder here, and a task in ZT Tasks';

  @override
  String get callBackLater => 'Call back later';

  @override
  String get in15Minutes => 'In 15 minutes';

  @override
  String get in1Hour => 'In 1 hour';

  @override
  String get in3Hours => 'In 3 hours';

  @override
  String get tonight => 'Tonight';

  @override
  String get tomorrowMorning => 'Tomorrow morning';

  @override
  String get pickATime => 'Pick a date and time';

  @override
  String get callBackExplain =>
      'ZT Phone reminds you at that time and adds a task to ZT Tasks. Both are done once you call back.';

  @override
  String callBackSetWithTask(String time) {
    return 'I\'ll remind you at $time. Added to ZT Tasks.';
  }

  @override
  String callBackSetNoTask(String time) {
    return 'I\'ll remind you at $time. ZT Tasks couldn\'t be reached, so no task was added.';
  }

  @override
  String callBackTaskTitle(String name) {
    return 'Call $name back';
  }

  @override
  String callBackName(String name) {
    return 'Call back $name';
  }

  @override
  String callBackDue(String time) {
    return 'Due since $time';
  }

  @override
  String get cancelReminder => 'Cancel reminder';

  @override
  String get nativeCallBackReminder => 'Call back %s';

  @override
  String get nativeCallBackChannel => 'Call back reminders';

  @override
  String get nativeRemindMe => 'Remind me';

  @override
  String get numberHiddenNotice =>
      'Your number is hidden on this call if your carrier allows it. Emergency numbers always see it.';

  @override
  String get privateLogLimitsTitle => 'Before you turn it on';

  @override
  String get privateLogLimitsIntro =>
      'ZT Phone moves these calls into your vault, but Android doesn\'t let any Phone app keep a call out of its shared history entirely:';

  @override
  String get privateLogLimitSeconds =>
      'Each call shows in Android\'s shared history for a few seconds after it ends, until ZT Phone moves it.';

  @override
  String get privateLogLimitDefault =>
      'If ZT Phone isn\'t your default Phone app, calls stay there until you next open ZT Phone.';

  @override
  String get privateLogLimitCarrier =>
      'Your carrier\'s records and bill still list every call.';

  @override
  String get turnOn => 'Turn on';
}
