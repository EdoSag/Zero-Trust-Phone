import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_en.dart';
import 'app_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @privateNumber.
  ///
  /// In en, this message translates to:
  /// **'Private number'**
  String get privateNumber;

  /// No description provided for @voicemail.
  ///
  /// In en, this message translates to:
  /// **'Voicemail'**
  String get voicemail;

  /// No description provided for @callName.
  ///
  /// In en, this message translates to:
  /// **'Call {name}'**
  String callName(String name);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @retentionForever.
  ///
  /// In en, this message translates to:
  /// **'Forever'**
  String get retentionForever;

  /// No description provided for @retention24h.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get retention24h;

  /// No description provided for @retentionDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String retentionDays(int days);

  /// No description provided for @dialpadNoUnlock.
  ///
  /// In en, this message translates to:
  /// **'Dialpad, no unlock needed'**
  String get dialpadNoUnlock;

  /// No description provided for @conferenceCall.
  ///
  /// In en, this message translates to:
  /// **'Conference call'**
  String get conferenceCall;

  /// No description provided for @callEnded.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get callEnded;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @endCall.
  ///
  /// In en, this message translates to:
  /// **'End call'**
  String get endCall;

  /// No description provided for @declineWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Decline and send a message'**
  String get declineWithMessage;

  /// No description provided for @writeYourOwn.
  ///
  /// In en, this message translates to:
  /// **'Write your own…'**
  String get writeYourOwn;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @carAudio.
  ///
  /// In en, this message translates to:
  /// **'Car audio'**
  String get carAudio;

  /// No description provided for @phoneAudio.
  ///
  /// In en, this message translates to:
  /// **'Phone audio'**
  String get phoneAudio;

  /// No description provided for @speaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get speaker;

  /// No description provided for @incomingCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get incomingCall;

  /// No description provided for @chooseSim.
  ///
  /// In en, this message translates to:
  /// **'Choose a SIM'**
  String get chooseSim;

  /// No description provided for @calling.
  ///
  /// In en, this message translates to:
  /// **'Calling…'**
  String get calling;

  /// No description provided for @onHold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get onHold;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @callWithAccount.
  ///
  /// In en, this message translates to:
  /// **'Call with {account}'**
  String callWithAccount(String account);

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @endAndAnswer.
  ///
  /// In en, this message translates to:
  /// **'End & answer'**
  String get endAndAnswer;

  /// No description provided for @holdAndAnswer.
  ///
  /// In en, this message translates to:
  /// **'Hold & answer'**
  String get holdAndAnswer;

  /// No description provided for @answer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get answer;

  /// No description provided for @replyWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Reply with a message'**
  String get replyWithMessage;

  /// No description provided for @keypad.
  ///
  /// In en, this message translates to:
  /// **'Keypad'**
  String get keypad;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @hold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get hold;

  /// No description provided for @merge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

  /// No description provided for @addCall.
  ///
  /// In en, this message translates to:
  /// **'Add call'**
  String get addCall;

  /// No description provided for @bluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get bluetooth;

  /// No description provided for @headset.
  ///
  /// In en, this message translates to:
  /// **'Headset'**
  String get headset;

  /// No description provided for @phoneEarpiece.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneEarpiece;

  /// No description provided for @swap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get swap;

  /// No description provided for @defaultPhoneApp.
  ///
  /// In en, this message translates to:
  /// **'Default Phone app'**
  String get defaultPhoneApp;

  /// No description provided for @defaultPhoneAppOn.
  ///
  /// In en, this message translates to:
  /// **'ZT Phone handles your calls'**
  String get defaultPhoneAppOn;

  /// No description provided for @defaultPhoneAppOff.
  ///
  /// In en, this message translates to:
  /// **'Another app handles calls. Tap to switch to ZT Phone'**
  String get defaultPhoneAppOff;

  /// No description provided for @namesFromContacts.
  ///
  /// In en, this message translates to:
  /// **'Names from ZT Contacts'**
  String get namesFromContacts;

  /// No description provided for @namesFromContactsBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 contact, encrypted on this phone. Edit them in ZT Contacts} other{{count} contacts, encrypted on this phone. Edit them in ZT Contacts}}'**
  String namesFromContactsBody(int count);

  /// No description provided for @keepCallHistory.
  ///
  /// In en, this message translates to:
  /// **'Keep call history'**
  String get keepCallHistory;

  /// No description provided for @callProtection.
  ///
  /// In en, this message translates to:
  /// **'Call protection'**
  String get callProtection;

  /// No description provided for @blockedNumbers.
  ///
  /// In en, this message translates to:
  /// **'Blocked numbers'**
  String get blockedNumbers;

  /// No description provided for @quickReplies.
  ///
  /// In en, this message translates to:
  /// **'Quick replies'**
  String get quickReplies;

  /// No description provided for @quickRepliesBody.
  ///
  /// In en, this message translates to:
  /// **'Texts to send when you decline a call'**
  String get quickRepliesBody;

  /// No description provided for @speedDial.
  ///
  /// In en, this message translates to:
  /// **'Speed dial'**
  String get speedDial;

  /// No description provided for @speedDialBody.
  ///
  /// In en, this message translates to:
  /// **'Hold 2 to 9 on the dialpad'**
  String get speedDialBody;

  /// No description provided for @voicemailBody.
  ///
  /// In en, this message translates to:
  /// **'Hold 1 on the dialpad to call it. Tap for your carrier\'s voicemail settings'**
  String get voicemailBody;

  /// No description provided for @callHistoryBackup.
  ///
  /// In en, this message translates to:
  /// **'Call history backup'**
  String get callHistoryBackup;

  /// No description provided for @backupOn.
  ///
  /// In en, this message translates to:
  /// **'On, end-to-end encrypted'**
  String get backupOn;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @dndStarred.
  ///
  /// In en, this message translates to:
  /// **'Do Not Disturb and starred contacts'**
  String get dndStarred;

  /// No description provided for @dndStarredBody.
  ///
  /// In en, this message translates to:
  /// **'Android lets starred contacts through Do Not Disturb only if it can see them. Turn on \"Show in Phone and Messages\" in ZT Contacts settings for that.'**
  String get dndStarredBody;

  /// No description provided for @unknownSilenced.
  ///
  /// In en, this message translates to:
  /// **'Unknown callers silenced'**
  String get unknownSilenced;

  /// No description provided for @unknownToVoicemail.
  ///
  /// In en, this message translates to:
  /// **'Unknown callers to voicemail'**
  String get unknownToVoicemail;

  /// No description provided for @hiddenBlocked.
  ///
  /// In en, this message translates to:
  /// **'hidden numbers blocked'**
  String get hiddenBlocked;

  /// No description provided for @prefixesBlocked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 blocked prefix} other{{count} blocked prefixes}}'**
  String prefixesBlocked(int count);

  /// No description provided for @protectionOff.
  ///
  /// In en, this message translates to:
  /// **'Off. Silence unknown callers, block hidden numbers or prefixes'**
  String get protectionOff;

  /// No description provided for @retentionBody.
  ///
  /// In en, this message translates to:
  /// **'Older calls are deleted from this phone\'s call history, also for other apps.'**
  String get retentionBody;

  /// No description provided for @addANumber.
  ///
  /// In en, this message translates to:
  /// **'Add a number'**
  String get addANumber;

  /// No description provided for @noBlockedNumbers.
  ///
  /// In en, this message translates to:
  /// **'No blocked numbers.\nBlock a number from Recents or from here.'**
  String get noBlockedNumbers;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @blockANumber.
  ///
  /// In en, this message translates to:
  /// **'Block a number'**
  String get blockANumber;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @sendAMessage.
  ///
  /// In en, this message translates to:
  /// **'Send a message'**
  String get sendAMessage;

  /// No description provided for @callHistory.
  ///
  /// In en, this message translates to:
  /// **'Call history'**
  String get callHistory;

  /// No description provided for @ringtoneVoicemailSim.
  ///
  /// In en, this message translates to:
  /// **'Ringtone, voicemail and SIM'**
  String get ringtoneVoicemailSim;

  /// No description provided for @addToContacts.
  ///
  /// In en, this message translates to:
  /// **'Add to contacts'**
  String get addToContacts;

  /// No description provided for @editBeforeCalling.
  ///
  /// In en, this message translates to:
  /// **'Edit number before calling'**
  String get editBeforeCalling;

  /// No description provided for @copyNumber.
  ///
  /// In en, this message translates to:
  /// **'Copy number'**
  String get copyNumber;

  /// No description provided for @blockNumber.
  ///
  /// In en, this message translates to:
  /// **'Block number'**
  String get blockNumber;

  /// No description provided for @blockNumberBody.
  ///
  /// In en, this message translates to:
  /// **'Calls from it are silently declined'**
  String get blockNumberBody;

  /// No description provided for @setAsPhoneToBlock.
  ///
  /// In en, this message translates to:
  /// **'Set ZT Phone as your Phone app to block numbers'**
  String get setAsPhoneToBlock;

  /// No description provided for @blockNumberQuestion.
  ///
  /// In en, this message translates to:
  /// **'Block {number}?'**
  String blockNumberQuestion(String number);

  /// No description provided for @blockNumberExplain.
  ///
  /// In en, this message translates to:
  /// **'You won\'t get calls or texts from this number. Android keeps the list, so it also applies in other phone and messaging apps.'**
  String get blockNumberExplain;

  /// No description provided for @numberBlocked.
  ///
  /// In en, this message translates to:
  /// **'{number} blocked'**
  String numberBlocked(String number);

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @quickRepliesExplain.
  ///
  /// In en, this message translates to:
  /// **'Offered when a call comes in. The text goes out through your messaging app, from your number.'**
  String get quickRepliesExplain;

  /// No description provided for @newReply.
  ///
  /// In en, this message translates to:
  /// **'New reply'**
  String get newReply;

  /// No description provided for @editReply.
  ///
  /// In en, this message translates to:
  /// **'Edit reply'**
  String get editReply;

  /// No description provided for @unlockToChangeSpeedDial.
  ///
  /// In en, this message translates to:
  /// **'Unlock ZT Phone to change speed dial'**
  String get unlockToChangeSpeedDial;

  /// No description provided for @hold1.
  ///
  /// In en, this message translates to:
  /// **'Hold 1 on the dialpad'**
  String get hold1;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @speedDialExplain.
  ///
  /// In en, this message translates to:
  /// **'Hold a number on the dialpad to call. Saved encrypted in your account.'**
  String get speedDialExplain;

  /// No description provided for @speedDialSearch.
  ///
  /// In en, this message translates to:
  /// **'Speed dial {digit}: search contacts'**
  String speedDialSearch(int digit);

  /// No description provided for @noContactsWithNumber.
  ///
  /// In en, this message translates to:
  /// **'No contacts with a phone number'**
  String get noContactsWithNumber;

  /// No description provided for @backUpCallHistory.
  ///
  /// In en, this message translates to:
  /// **'Back up call history'**
  String get backUpCallHistory;

  /// No description provided for @backUpCallHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted in your account, so a new phone can get it back. Only you can read it.'**
  String get backUpCallHistoryBody;

  /// No description provided for @backedUpCalls.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Backed up 1 call} other{Backed up {count} calls}}'**
  String backedUpCalls(int count);

  /// No description provided for @backupDeleted.
  ///
  /// In en, this message translates to:
  /// **'Backup turned off and deleted'**
  String get backupDeleted;

  /// No description provided for @backUpNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backUpNow;

  /// No description provided for @alreadyUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get alreadyUpToDate;

  /// No description provided for @restoreToPhone.
  ///
  /// In en, this message translates to:
  /// **'Restore to this phone'**
  String get restoreToPhone;

  /// No description provided for @restoreToPhoneBody.
  ///
  /// In en, this message translates to:
  /// **'Adds backed-up calls missing from this phone\'s history'**
  String get restoreToPhoneBody;

  /// No description provided for @nothingToRestore.
  ///
  /// In en, this message translates to:
  /// **'Nothing to restore'**
  String get nothingToRestore;

  /// No description provided for @restoredCalls.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Restored 1 call} other{Restored {count} calls}}'**
  String restoredCalls(int count);

  /// No description provided for @backupExplain.
  ///
  /// In en, this message translates to:
  /// **'The backup follows \"Keep call history\": older calls are removed from it too. Deleting a call in Recents also deletes its backup.'**
  String get backupExplain;

  /// No description provided for @unknownCallersHeader.
  ///
  /// In en, this message translates to:
  /// **'Calls from numbers not in your contacts'**
  String get unknownCallersHeader;

  /// No description provided for @blockHidden.
  ///
  /// In en, this message translates to:
  /// **'Block hidden numbers'**
  String get blockHidden;

  /// No description provided for @blockHiddenBody.
  ///
  /// In en, this message translates to:
  /// **'Private and unknown caller IDs'**
  String get blockHiddenBody;

  /// No description provided for @blockedPrefixes.
  ///
  /// In en, this message translates to:
  /// **'Blocked prefixes and countries'**
  String get blockedPrefixes;

  /// No description provided for @blockedPrefixesBody.
  ///
  /// In en, this message translates to:
  /// **'Block every number that starts with, for example, +1900 or a whole country such as +44'**
  String get blockedPrefixesBody;

  /// No description provided for @addPrefix.
  ///
  /// In en, this message translates to:
  /// **'Add prefix'**
  String get addPrefix;

  /// No description provided for @removePrefix.
  ///
  /// In en, this message translates to:
  /// **'Remove {prefix}'**
  String removePrefix(String prefix);

  /// No description provided for @protectionExplain.
  ///
  /// In en, this message translates to:
  /// **'Contacts you block or send to voicemail in ZT Contacts are handled here too. Rules work while ZT Phone is locked, and your contacts always ring unless you send them to voicemail.'**
  String get protectionExplain;

  /// No description provided for @blockStartingWith.
  ///
  /// In en, this message translates to:
  /// **'Block numbers starting with'**
  String get blockStartingWith;

  /// No description provided for @unknownRing.
  ///
  /// In en, this message translates to:
  /// **'Ring as usual'**
  String get unknownRing;

  /// No description provided for @unknownSilence.
  ///
  /// In en, this message translates to:
  /// **'Silence (they still show in Recents)'**
  String get unknownSilence;

  /// No description provided for @unknownVoicemail.
  ///
  /// In en, this message translates to:
  /// **'Send to voicemail'**
  String get unknownVoicemail;

  /// No description provided for @couldntOpenContacts.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open your contacts. {reason}'**
  String couldntOpenContacts(String reason);

  /// No description provided for @noContactsMatch.
  ///
  /// In en, this message translates to:
  /// **'No contacts match \"{query}\"'**
  String noContactsMatch(String query);

  /// No description provided for @noFavoritesContacts.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet.\nStar contacts in ZT Contacts and they show up here.'**
  String get noFavoritesContacts;

  /// No description provided for @contactsComeFrom.
  ///
  /// In en, this message translates to:
  /// **'Your contacts come from ZT Contacts, end-to-end encrypted with the same account. Add some there and they show up here.'**
  String get contactsComeFrom;

  /// No description provided for @getZtContacts.
  ///
  /// In en, this message translates to:
  /// **'Get ZT Contacts'**
  String get getZtContacts;

  /// No description provided for @deleteThisHistory.
  ///
  /// In en, this message translates to:
  /// **'Delete this history'**
  String get deleteThisHistory;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @callSettings.
  ///
  /// In en, this message translates to:
  /// **'Call settings'**
  String get callSettings;

  /// No description provided for @noCallsInHistory.
  ///
  /// In en, this message translates to:
  /// **'No calls in this phone\'s history.'**
  String get noCallsInHistory;

  /// No description provided for @dayAndTime.
  ///
  /// In en, this message translates to:
  /// **'{day}, {time}'**
  String dayAndTime(String day, String time);

  /// No description provided for @deleteCallsQuestion.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete 1 call from history?} other{Delete {count} calls from history?}}'**
  String deleteCallsQuestion(int count);

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} sec'**
  String durationSeconds(int seconds);

  /// No description provided for @incoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get incoming;

  /// No description provided for @outgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing'**
  String get outgoing;

  /// No description provided for @missed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get missed;

  /// No description provided for @declined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get declined;

  /// No description provided for @blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blocked;

  /// No description provided for @noFavoritesFrequent.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet.\nStar contacts in ZT Contacts and they show up here, with the people you call most.'**
  String get noFavoritesFrequent;

  /// No description provided for @frequent.
  ///
  /// In en, this message translates to:
  /// **'Frequent'**
  String get frequent;

  /// No description provided for @searchCalls.
  ///
  /// In en, this message translates to:
  /// **'Search calls'**
  String get searchCalls;

  /// No description provided for @searchContacts.
  ///
  /// In en, this message translates to:
  /// **'Search contacts'**
  String get searchContacts;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @dialpad.
  ///
  /// In en, this message translates to:
  /// **'Dialpad'**
  String get dialpad;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @recents.
  ///
  /// In en, this message translates to:
  /// **'Recents'**
  String get recents;

  /// No description provided for @contacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// No description provided for @callAlertsOff.
  ///
  /// In en, this message translates to:
  /// **'Incoming calls can\'t show on the lock screen or as a notification. Allow call notifications for ZT Phone.'**
  String get callAlertsOff;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @makeDefault.
  ///
  /// In en, this message translates to:
  /// **'Make ZT Phone your Phone app to answer calls here, see your call history and block numbers.'**
  String get makeDefault;

  /// No description provided for @setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get setAsDefault;

  /// No description provided for @ringtone.
  ///
  /// In en, this message translates to:
  /// **'Ringtone'**
  String get ringtone;

  /// No description provided for @phoneRingtone.
  ///
  /// In en, this message translates to:
  /// **'The phone\'s ringtone'**
  String get phoneRingtone;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @sendToVoicemail.
  ///
  /// In en, this message translates to:
  /// **'Send calls to voicemail'**
  String get sendToVoicemail;

  /// No description provided for @sendToVoicemailBody.
  ///
  /// In en, this message translates to:
  /// **'Their calls don\'t ring; they can leave a message'**
  String get sendToVoicemailBody;

  /// No description provided for @callWith.
  ///
  /// In en, this message translates to:
  /// **'Call with'**
  String get callWith;

  /// No description provided for @askOrDefault.
  ///
  /// In en, this message translates to:
  /// **'Ask or use the default'**
  String get askOrDefault;

  /// No description provided for @callSettingsExplain.
  ///
  /// In en, this message translates to:
  /// **'Saved encrypted in your account, so a new phone gets them too. They work while ZT Phone is locked; the phone keeps only a scrambled form of the numbers for that.'**
  String get callSettingsExplain;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @couldntReadHistory.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read your call history.\n{reason}'**
  String couldntReadHistory(String reason);

  /// No description provided for @noCallsMatch.
  ///
  /// In en, this message translates to:
  /// **'No calls match \"{query}\"'**
  String noCallsMatch(String query);

  /// No description provided for @noCallsYet.
  ///
  /// In en, this message translates to:
  /// **'No calls yet.\nCalls you make and get show up here.'**
  String get noCallsYet;

  /// No description provided for @noMissedCalls.
  ///
  /// In en, this message translates to:
  /// **'No missed calls'**
  String get noMissedCalls;

  /// No description provided for @noIncomingCalls.
  ///
  /// In en, this message translates to:
  /// **'No incoming calls'**
  String get noIncomingCalls;

  /// No description provided for @noOutgoingCalls.
  ///
  /// In en, this message translates to:
  /// **'No outgoing calls'**
  String get noOutgoingCalls;

  /// No description provided for @noBlockedCalls.
  ///
  /// In en, this message translates to:
  /// **'No blocked calls'**
  String get noBlockedCalls;

  /// No description provided for @deleteThisCall.
  ///
  /// In en, this message translates to:
  /// **'Delete this call from history?'**
  String get deleteThisCall;

  /// No description provided for @noSpeedDialOn.
  ///
  /// In en, this message translates to:
  /// **'No speed dial on {digit}'**
  String noSpeedDialOn(String digit);

  /// No description provided for @pickContactForKey.
  ///
  /// In en, this message translates to:
  /// **'Pick a contact to call when you hold this key.'**
  String get pickContactForKey;

  /// No description provided for @pickContact.
  ///
  /// In en, this message translates to:
  /// **'Pick contact'**
  String get pickContact;

  /// No description provided for @keyZeroHold.
  ///
  /// In en, this message translates to:
  /// **'0, hold for plus'**
  String get keyZeroHold;

  /// No description provided for @keyOneHold.
  ///
  /// In en, this message translates to:
  /// **'1, hold for voicemail'**
  String get keyOneHold;

  /// No description provided for @nativePrivateNumber.
  ///
  /// In en, this message translates to:
  /// **'Private number'**
  String get nativePrivateNumber;

  /// No description provided for @nativeMissedCall.
  ///
  /// In en, this message translates to:
  /// **'Missed call'**
  String get nativeMissedCall;

  /// No description provided for @nativeMissedCalls.
  ///
  /// In en, this message translates to:
  /// **'%d missed calls'**
  String get nativeMissedCalls;

  /// No description provided for @nativeLatestFrom.
  ///
  /// In en, this message translates to:
  /// **'Latest from %s'**
  String get nativeLatestFrom;

  /// No description provided for @nativeCallBack.
  ///
  /// In en, this message translates to:
  /// **'Call back'**
  String get nativeCallBack;

  /// No description provided for @nativeNewVoicemail.
  ///
  /// In en, this message translates to:
  /// **'New voicemail'**
  String get nativeNewVoicemail;

  /// No description provided for @nativeVoicemailMessages.
  ///
  /// In en, this message translates to:
  /// **'%d messages. Tap to call voicemail'**
  String get nativeVoicemailMessages;

  /// No description provided for @nativeTapToCallVoicemail.
  ///
  /// In en, this message translates to:
  /// **'Tap to call voicemail'**
  String get nativeTapToCallVoicemail;

  /// No description provided for @nativeCallVoicemail.
  ///
  /// In en, this message translates to:
  /// **'Call voicemail'**
  String get nativeCallVoicemail;

  /// No description provided for @nativeMissedChannel.
  ///
  /// In en, this message translates to:
  /// **'Missed calls'**
  String get nativeMissedChannel;

  /// No description provided for @nativeIncomingChannel.
  ///
  /// In en, this message translates to:
  /// **'Incoming calls'**
  String get nativeIncomingChannel;

  /// No description provided for @nativeOngoingChannel.
  ///
  /// In en, this message translates to:
  /// **'Ongoing calls'**
  String get nativeOngoingChannel;

  /// No description provided for @nativeOngoingCall.
  ///
  /// In en, this message translates to:
  /// **'Ongoing call'**
  String get nativeOngoingCall;

  /// No description provided for @nativeHangUp.
  ///
  /// In en, this message translates to:
  /// **'Hang up'**
  String get nativeHangUp;

  /// No description provided for @replyCantTalk.
  ///
  /// In en, this message translates to:
  /// **'Can\'t talk now. I\'ll call you back.'**
  String get replyCantTalk;

  /// No description provided for @replyDriving.
  ///
  /// In en, this message translates to:
  /// **'I\'m driving. I\'ll call you soon.'**
  String get replyDriving;

  /// No description provided for @replyMeeting.
  ///
  /// In en, this message translates to:
  /// **'In a meeting. Can you text me?'**
  String get replyMeeting;

  /// No description provided for @replyOnMyWay.
  ///
  /// In en, this message translates to:
  /// **'On my way.'**
  String get replyOnMyWay;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @rtt.
  ///
  /// In en, this message translates to:
  /// **'RTT'**
  String get rtt;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @videoCall.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get videoCall;

  /// No description provided for @incomingVideoCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming video call'**
  String get incomingVideoCall;

  /// No description provided for @answerVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get answerVoice;

  /// No description provided for @answerVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get answerVideo;

  /// No description provided for @rttRequestBody.
  ///
  /// In en, this message translates to:
  /// **'They want to switch to real-time text (RTT).'**
  String get rttRequestBody;

  /// No description provided for @videoRequestBody.
  ///
  /// In en, this message translates to:
  /// **'They want to switch to video.'**
  String get videoRequestBody;

  /// No description provided for @rttFailed.
  ///
  /// In en, this message translates to:
  /// **'Real-time text isn\'t available on this call.'**
  String get rttFailed;

  /// No description provided for @videoFailed.
  ///
  /// In en, this message translates to:
  /// **'Video couldn\'t start. Your carrier may not allow it on this call.'**
  String get videoFailed;

  /// No description provided for @rttHint.
  ///
  /// In en, this message translates to:
  /// **'Type to talk. They see each letter as you type it, and their words appear here as they type.'**
  String get rttHint;

  /// No description provided for @rttTypeHere.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get rttTypeHere;

  /// No description provided for @rttSeesTyping.
  ///
  /// In en, this message translates to:
  /// **'Sent as you type'**
  String get rttSeesTyping;

  /// No description provided for @rttYouSaid.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get rttYouSaid;

  /// No description provided for @rttTheySaid.
  ///
  /// In en, this message translates to:
  /// **'Them'**
  String get rttTheySaid;

  /// No description provided for @waitingForVideo.
  ///
  /// In en, this message translates to:
  /// **'Waiting for video'**
  String get waitingForVideo;

  /// No description provided for @cameraOff.
  ///
  /// In en, this message translates to:
  /// **'Camera off'**
  String get cameraOff;

  /// No description provided for @cameraOn.
  ///
  /// In en, this message translates to:
  /// **'Camera on'**
  String get cameraOn;

  /// No description provided for @switchCamera.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get switchCamera;

  /// No description provided for @voiceOnly.
  ///
  /// In en, this message translates to:
  /// **'Voice only'**
  String get voiceOnly;

  /// No description provided for @callAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility and video'**
  String get callAccessibility;

  /// No description provided for @callAccessibilityBody.
  ///
  /// In en, this message translates to:
  /// **'Real-time text (RTT), TTY and video calls'**
  String get callAccessibilityBody;

  /// No description provided for @startWithRtt.
  ///
  /// In en, this message translates to:
  /// **'Start calls with real-time text'**
  String get startWithRtt;

  /// No description provided for @startWithRttBody.
  ///
  /// In en, this message translates to:
  /// **'Type and read during calls, with or instead of talking. The other person sees each letter as you type. You can also turn on RTT during any call that supports it.'**
  String get startWithRttBody;

  /// No description provided for @rttAvailable.
  ///
  /// In en, this message translates to:
  /// **'Your carrier offers RTT on this phone'**
  String get rttAvailable;

  /// No description provided for @rttNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'RTT isn\'t offered on this phone right now'**
  String get rttNotAvailable;

  /// No description provided for @rttNotAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'RTT needs your carrier\'s support. On many phones it also needs RTT switched on in Android\'s accessibility settings, under TTY and RTT below.'**
  String get rttNotAvailableBody;

  /// No description provided for @videoCalling.
  ///
  /// In en, this message translates to:
  /// **'Carrier video calls'**
  String get videoCalling;

  /// No description provided for @videoAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available. Look for the video button when you call, or turn video on during a call.'**
  String get videoAvailable;

  /// No description provided for @videoNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not offered right now. Video calls need your carrier\'s VoLTE and video calling, which you may need to turn on in Android\'s SIM settings.'**
  String get videoNotAvailable;

  /// No description provided for @ttySettings.
  ///
  /// In en, this message translates to:
  /// **'TTY mode and RTT settings'**
  String get ttySettings;

  /// No description provided for @ttySettingsBody.
  ///
  /// In en, this message translates to:
  /// **'Opens your phone\'s built-in call accessibility settings. Android lets only the built-in Phone app change TTY mode.'**
  String get ttySettingsBody;

  /// No description provided for @ttySettingsMissing.
  ///
  /// In en, this message translates to:
  /// **'This phone has no built-in screen for TTY mode, and Android doesn\'t let other apps change it.'**
  String get ttySettingsMissing;

  /// No description provided for @callAccessibilityPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Real-time text and video go over your carrier\'s network, straight to the other person. ZT Phone never sends them to its servers or keeps them after the call.'**
  String get callAccessibilityPrivacy;

  /// No description provided for @pasteNumber.
  ///
  /// In en, this message translates to:
  /// **'Paste a number'**
  String get pasteNumber;

  /// No description provided for @noNumberInText.
  ///
  /// In en, this message translates to:
  /// **'No phone number found in the copied text'**
  String get noNumberInText;

  /// No description provided for @whichNumber.
  ///
  /// In en, this message translates to:
  /// **'Which number?'**
  String get whichNumber;

  /// No description provided for @dialWithPauses.
  ///
  /// In en, this message translates to:
  /// **'Dial with pauses'**
  String get dialWithPauses;

  /// No description provided for @dialWithPausesShort.
  ///
  /// In en, this message translates to:
  /// **'Wait, then send a code or menu choice'**
  String get dialWithPausesShort;

  /// No description provided for @dialWithPausesExplain.
  ///
  /// In en, this message translates to:
  /// **'For phone menus, conference codes and voicemail PINs: call, wait, then send the digits for you. Save it and it\'s one tap next time.'**
  String get dialWithPausesExplain;

  /// No description provided for @dialShortcutDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Call with code'**
  String get dialShortcutDefaultLabel;

  /// No description provided for @dialShortcutName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get dialShortcutName;

  /// No description provided for @dialShortcutNameHint.
  ///
  /// In en, this message translates to:
  /// **'Voicemail PIN, Work conference…'**
  String get dialShortcutNameHint;

  /// No description provided for @numberToCall.
  ///
  /// In en, this message translates to:
  /// **'Number to call'**
  String get numberToCall;

  /// No description provided for @addPause.
  ///
  /// In en, this message translates to:
  /// **'Wait 3 seconds'**
  String get addPause;

  /// No description provided for @addWaitForTap.
  ///
  /// In en, this message translates to:
  /// **'Wait for my tap'**
  String get addWaitForTap;

  /// No description provided for @addTones.
  ///
  /// In en, this message translates to:
  /// **'Send digits'**
  String get addTones;

  /// No description provided for @dialsAs.
  ///
  /// In en, this message translates to:
  /// **'Dials'**
  String get dialsAs;

  /// No description provided for @callNow.
  ///
  /// In en, this message translates to:
  /// **'Call now'**
  String get callNow;

  /// No description provided for @pauseSeconds.
  ///
  /// In en, this message translates to:
  /// **'Wait about {seconds} seconds'**
  String pauseSeconds(int seconds);

  /// No description provided for @shorterPause.
  ///
  /// In en, this message translates to:
  /// **'Shorter'**
  String get shorterPause;

  /// No description provided for @longerPause.
  ///
  /// In en, this message translates to:
  /// **'Longer'**
  String get longerPause;

  /// No description provided for @waitForTapStep.
  ///
  /// In en, this message translates to:
  /// **'Wait until I tap Send on the call screen'**
  String get waitForTapStep;

  /// No description provided for @tonesToSend.
  ///
  /// In en, this message translates to:
  /// **'Digits to send'**
  String get tonesToSend;

  /// No description provided for @removeStep.
  ///
  /// In en, this message translates to:
  /// **'Remove step'**
  String get removeStep;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @hideMyNumber.
  ///
  /// In en, this message translates to:
  /// **'Hide my number on this call'**
  String get hideMyNumber;

  /// No description provided for @showMyNumber.
  ///
  /// In en, this message translates to:
  /// **'Show my number on this call'**
  String get showMyNumber;

  /// No description provided for @numberHidden.
  ///
  /// In en, this message translates to:
  /// **'My number hidden'**
  String get numberHidden;

  /// No description provided for @keyStarHold.
  ///
  /// In en, this message translates to:
  /// **'Star, hold for a pause'**
  String get keyStarHold;

  /// No description provided for @keyHashHold.
  ///
  /// In en, this message translates to:
  /// **'Hash, hold for wait'**
  String get keyHashHold;

  /// No description provided for @callWithNumberHidden.
  ///
  /// In en, this message translates to:
  /// **'Call with my number hidden'**
  String get callWithNumberHidden;

  /// No description provided for @callWithNumberHiddenBody.
  ///
  /// In en, this message translates to:
  /// **'They see \"Private number\", if your carrier allows it'**
  String get callWithNumberHiddenBody;

  /// No description provided for @hideMyNumberForContact.
  ///
  /// In en, this message translates to:
  /// **'Hide my number'**
  String get hideMyNumberForContact;

  /// No description provided for @hideMyNumberForContactBody.
  ///
  /// In en, this message translates to:
  /// **'Every call to this contact shows \"Private number\", if your carrier allows it'**
  String get hideMyNumberForContactBody;

  /// No description provided for @timeTomorrow.
  ///
  /// In en, this message translates to:
  /// **'{time} tomorrow'**
  String timeTomorrow(String time);

  /// No description provided for @timeYesterday.
  ///
  /// In en, this message translates to:
  /// **'{time} yesterday'**
  String timeYesterday(String time);

  /// No description provided for @timeRange.
  ///
  /// In en, this message translates to:
  /// **'{from}–{to}'**
  String timeRange(String from, String to);

  /// No description provided for @countryTimeThere.
  ///
  /// In en, this message translates to:
  /// **'{country} · {time} there now'**
  String countryTimeThere(String country, String time);

  /// No description provided for @sendTonesQuestion.
  ///
  /// In en, this message translates to:
  /// **'Send {tones} now?'**
  String sendTonesQuestion(String tones);

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @privateCallLog.
  ///
  /// In en, this message translates to:
  /// **'Private call log'**
  String get privateCallLog;

  /// No description provided for @privateCallLogBody.
  ///
  /// In en, this message translates to:
  /// **'Calls with this contact are kept only in your encrypted vault, not in Android\'s shared call history that other apps can read'**
  String get privateCallLogBody;

  /// No description provided for @movedToVault.
  ///
  /// In en, this message translates to:
  /// **'Moved {count} past calls into the vault'**
  String movedToVault(int count);

  /// No description provided for @callStats.
  ///
  /// In en, this message translates to:
  /// **'Call stats'**
  String get callStats;

  /// No description provided for @statsWeek.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get statsWeek;

  /// No description provided for @statsMonth.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get statsMonth;

  /// No description provided for @statsYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get statsYear;

  /// No description provided for @statsCalls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get statsCalls;

  /// No description provided for @statsInOut.
  ///
  /// In en, this message translates to:
  /// **'{incoming} in · {outgoing} out'**
  String statsInOut(int incoming, int outgoing);

  /// No description provided for @statsTalkTime.
  ///
  /// In en, this message translates to:
  /// **'Talk time'**
  String get statsTalkTime;

  /// No description provided for @statsAverageCall.
  ///
  /// In en, this message translates to:
  /// **'Average call'**
  String get statsAverageCall;

  /// No description provided for @statsLastWeeks.
  ///
  /// In en, this message translates to:
  /// **'Last 8 weeks'**
  String get statsLastWeeks;

  /// No description provided for @statsMostTalked.
  ///
  /// In en, this message translates to:
  /// **'Who you talk to most'**
  String get statsMostTalked;

  /// No description provided for @statsPersonLine.
  ///
  /// In en, this message translates to:
  /// **'{calls} calls · {talk}'**
  String statsPersonLine(int calls, String talk);

  /// No description provided for @statsWeekBar.
  ///
  /// In en, this message translates to:
  /// **'Week of {start}: {calls} calls, {talk}'**
  String statsWeekBar(String start, int calls, String talk);

  /// No description provided for @statsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Worked out on this phone from your call history. Nothing is sent anywhere.'**
  String get statsPrivacy;

  /// No description provided for @talkMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String talkMinutes(int minutes);

  /// No description provided for @talkHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String talkHoursMinutes(int hours, int minutes);

  /// No description provided for @remindMeToCallBack.
  ///
  /// In en, this message translates to:
  /// **'Remind me to call {name} back'**
  String remindMeToCallBack(String name);

  /// No description provided for @remindMeToCallBackShort.
  ///
  /// In en, this message translates to:
  /// **'Remind me to call back'**
  String get remindMeToCallBackShort;

  /// No description provided for @remindMeToCallBackBody.
  ///
  /// In en, this message translates to:
  /// **'A reminder here, and a task in ZT Tasks'**
  String get remindMeToCallBackBody;

  /// No description provided for @callBackLater.
  ///
  /// In en, this message translates to:
  /// **'Call back later'**
  String get callBackLater;

  /// No description provided for @in15Minutes.
  ///
  /// In en, this message translates to:
  /// **'In 15 minutes'**
  String get in15Minutes;

  /// No description provided for @in1Hour.
  ///
  /// In en, this message translates to:
  /// **'In 1 hour'**
  String get in1Hour;

  /// No description provided for @in3Hours.
  ///
  /// In en, this message translates to:
  /// **'In 3 hours'**
  String get in3Hours;

  /// No description provided for @tonight.
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get tonight;

  /// No description provided for @tomorrowMorning.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow morning'**
  String get tomorrowMorning;

  /// No description provided for @pickATime.
  ///
  /// In en, this message translates to:
  /// **'Pick a date and time'**
  String get pickATime;

  /// No description provided for @callBackExplain.
  ///
  /// In en, this message translates to:
  /// **'ZT Phone reminds you at that time and adds a task to ZT Tasks. Both are done once you call back.'**
  String get callBackExplain;

  /// No description provided for @callBackSetWithTask.
  ///
  /// In en, this message translates to:
  /// **'I\'ll remind you at {time}. Added to ZT Tasks.'**
  String callBackSetWithTask(String time);

  /// No description provided for @callBackSetNoTask.
  ///
  /// In en, this message translates to:
  /// **'I\'ll remind you at {time}. ZT Tasks couldn\'t be reached, so no task was added.'**
  String callBackSetNoTask(String time);

  /// No description provided for @callBackTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Call {name} back'**
  String callBackTaskTitle(String name);

  /// No description provided for @callBackName.
  ///
  /// In en, this message translates to:
  /// **'Call back {name}'**
  String callBackName(String name);

  /// No description provided for @callBackDue.
  ///
  /// In en, this message translates to:
  /// **'Due since {time}'**
  String callBackDue(String time);

  /// No description provided for @cancelReminder.
  ///
  /// In en, this message translates to:
  /// **'Cancel reminder'**
  String get cancelReminder;

  /// No description provided for @nativeCallBackReminder.
  ///
  /// In en, this message translates to:
  /// **'Call back %s'**
  String get nativeCallBackReminder;

  /// No description provided for @nativeCallBackChannel.
  ///
  /// In en, this message translates to:
  /// **'Call back reminders'**
  String get nativeCallBackChannel;

  /// No description provided for @nativeRemindMe.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get nativeRemindMe;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @exactRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Remind you on the minute?'**
  String get exactRemindersTitle;

  /// No description provided for @exactRemindersBody.
  ///
  /// In en, this message translates to:
  /// **'Android lets ZT Phone ring a reminder at the exact minute only if you allow \"Alarms & reminders\" for it. Without that, reminders still come, but can be a few minutes late.'**
  String get exactRemindersBody;

  /// No description provided for @callBackMayBeLate.
  ///
  /// In en, this message translates to:
  /// **'Reminders can be a few minutes late'**
  String get callBackMayBeLate;

  /// No description provided for @callBackMayBeLateBody.
  ///
  /// In en, this message translates to:
  /// **'Tap to allow \"Alarms & reminders\" for exact times'**
  String get callBackMayBeLateBody;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'he':
      return AppL10nHe();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
