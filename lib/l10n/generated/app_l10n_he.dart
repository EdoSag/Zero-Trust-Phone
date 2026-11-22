// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppL10nHe extends AppL10n {
  AppL10nHe([String locale = 'he']) : super(locale);

  @override
  String get cancel => 'ביטול';

  @override
  String get delete => 'מחיקה';

  @override
  String get save => 'שמירה';

  @override
  String get block => 'חסימה';

  @override
  String get call => 'שיחה';

  @override
  String get privateNumber => 'מספר חסוי';

  @override
  String get voicemail => 'תא קולי';

  @override
  String callName(String name) {
    return 'חיוג אל $name';
  }

  @override
  String get today => 'היום';

  @override
  String get yesterday => 'אתמול';

  @override
  String get retentionForever => 'לתמיד';

  @override
  String get retention24h => '24 שעות';

  @override
  String retentionDays(int days) {
    return '$days ימים';
  }

  @override
  String get dialpadNoUnlock => 'חייגן, בלי לבטל נעילה';

  @override
  String get conferenceCall => 'שיחת ועידה';

  @override
  String get callEnded => 'השיחה הסתיימה';

  @override
  String get hide => 'הסתרה';

  @override
  String get endCall => 'סיום שיחה';

  @override
  String get declineWithMessage => 'דחייה ושליחת הודעה';

  @override
  String get writeYourOwn => 'כתיבת הודעה משלך…';

  @override
  String get send => 'שליחה';

  @override
  String get mute => 'השתקה';

  @override
  String get unmute => 'ביטול השתקה';

  @override
  String get carAudio => 'שמע ברכב';

  @override
  String get phoneAudio => 'שמע בטלפון';

  @override
  String get speaker => 'רמקול';

  @override
  String get incomingCall => 'שיחה נכנסת';

  @override
  String get chooseSim => 'בחירת SIM';

  @override
  String get calling => 'מחייג…';

  @override
  String get onHold => 'בהמתנה';

  @override
  String get connected => 'מחובר';

  @override
  String callWithAccount(String account) {
    return 'חיוג עם $account';
  }

  @override
  String get decline => 'דחייה';

  @override
  String get endAndAnswer => 'סיום ומענה';

  @override
  String get holdAndAnswer => 'המתנה ומענה';

  @override
  String get answer => 'מענה';

  @override
  String get replyWithMessage => 'מענה בהודעה';

  @override
  String get keypad => 'מקלדת';

  @override
  String get audio => 'שמע';

  @override
  String get resume => 'המשך';

  @override
  String get hold => 'המתנה';

  @override
  String get merge => 'מיזוג';

  @override
  String get addCall => 'הוספת שיחה';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get headset => 'אוזניות';

  @override
  String get phoneEarpiece => 'טלפון';

  @override
  String get swap => 'החלפה';

  @override
  String get defaultPhoneApp => 'אפליקציית הטלפון שבברירת מחדל';

  @override
  String get defaultPhoneAppOn => 'ZT Phone מטפלת בשיחות שלך';

  @override
  String get defaultPhoneAppOff =>
      'אפליקציה אחרת מטפלת בשיחות. אפשר להקיש כדי לעבור ל-ZT Phone';

  @override
  String get namesFromContacts => 'שמות מ-ZT Contacts';

  @override
  String namesFromContactsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count אנשי קשר, מוצפנים בטלפון הזה. עורכים ב-ZT Contacts',
      one: 'איש קשר אחד, מוצפן בטלפון הזה. עורכים ב-ZT Contacts',
    );
    return '$_temp0';
  }

  @override
  String get keepCallHistory => 'שמירת היסטוריית השיחות';

  @override
  String get callProtection => 'הגנה מפני שיחות';

  @override
  String get blockedNumbers => 'מספרים חסומים';

  @override
  String get quickReplies => 'תשובות מהירות';

  @override
  String get quickRepliesBody => 'הודעות לשליחה כשדוחים שיחה';

  @override
  String get speedDial => 'חיוג מהיר';

  @override
  String get speedDialBody => 'לחיצה ארוכה על 2 עד 9 בחייגן';

  @override
  String get voicemailBody =>
      'לחיצה ארוכה על 1 בחייגן מחייגת אליו. אפשר להקיש להגדרות התא הקולי של הספק';

  @override
  String get callHistoryBackup => 'גיבוי היסטוריית השיחות';

  @override
  String get backupOn => 'מופעל, מוצפן מקצה לקצה';

  @override
  String get off => 'כבוי';

  @override
  String get dndStarred => 'נא לא להפריע ואנשי קשר מסומנים בכוכב';

  @override
  String get dndStarredBody =>
      'Android מעביר אנשי קשר מסומנים בכוכב דרך \"נא לא להפריע\" רק אם הוא רואה אותם. לשם כך צריך להפעיל את \"הצגה בטלפון ובהודעות\" בהגדרות של ZT Contacts.';

  @override
  String get unknownSilenced => 'מתקשרים לא מוכרים מושתקים';

  @override
  String get unknownToVoicemail => 'מתקשרים לא מוכרים מועברים לתא הקולי';

  @override
  String get hiddenBlocked => 'מספרים חסויים חסומים';

  @override
  String prefixesBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count קידומות חסומות',
      one: 'קידומת חסומה אחת',
    );
    return '$_temp0';
  }

  @override
  String get protectionOff =>
      'כבוי. אפשר להשתיק מתקשרים לא מוכרים, לחסום מספרים חסויים או קידומות';

  @override
  String get retentionBody =>
      'שיחות ישנות יותר נמחקות מהיסטוריית השיחות של הטלפון הזה, גם עבור אפליקציות אחרות.';

  @override
  String get addANumber => 'הוספת מספר';

  @override
  String get noBlockedNumbers =>
      'אין מספרים חסומים.\nאפשר לחסום מספר מהשיחות האחרונות או מכאן.';

  @override
  String get unblock => 'ביטול חסימה';

  @override
  String get blockANumber => 'חסימת מספר';

  @override
  String get phoneNumber => 'מספר טלפון';

  @override
  String get next => 'הבא';

  @override
  String get sendAMessage => 'שליחת הודעה';

  @override
  String get callHistory => 'היסטוריית שיחות';

  @override
  String get ringtoneVoicemailSim => 'רינגטון, תא קולי ו-SIM';

  @override
  String get addToContacts => 'הוספה לאנשי הקשר';

  @override
  String get editBeforeCalling => 'עריכת המספר לפני החיוג';

  @override
  String get copyNumber => 'העתקת המספר';

  @override
  String get blockNumber => 'חסימת המספר';

  @override
  String get blockNumberBody => 'שיחות ממנו נדחות בשקט';

  @override
  String get setAsPhoneToBlock =>
      'כדי לחסום מספרים צריך להגדיר את ZT Phone כאפליקציית הטלפון';

  @override
  String blockNumberQuestion(String number) {
    return 'לחסום את $number?';
  }

  @override
  String get blockNumberExplain =>
      'לא יגיעו שיחות או הודעות מהמספר הזה. Android שומר את הרשימה, כך שהיא חלה גם באפליקציות טלפון והודעות אחרות.';

  @override
  String numberBlocked(String number) {
    return '$number נחסם';
  }

  @override
  String get reset => 'איפוס';

  @override
  String get add => 'הוספה';

  @override
  String get quickRepliesExplain =>
      'מוצעות כשנכנסת שיחה. ההודעה נשלחת דרך אפליקציית ההודעות שלך, מהמספר שלך.';

  @override
  String get newReply => 'תשובה חדשה';

  @override
  String get editReply => 'עריכת תשובה';

  @override
  String get unlockToChangeSpeedDial =>
      'צריך לבטל את נעילת ZT Phone כדי לשנות חיוג מהיר';

  @override
  String get hold1 => 'לחיצה ארוכה על 1 בחייגן';

  @override
  String get notSet => 'לא הוגדר';

  @override
  String get remove => 'הסרה';

  @override
  String get speedDialExplain =>
      'לחיצה ארוכה על מספר בחייגן מחייגת. נשמר מוצפן בחשבון שלך.';

  @override
  String speedDialSearch(int digit) {
    return 'חיוג מהיר $digit: חיפוש אנשי קשר';
  }

  @override
  String get noContactsWithNumber => 'אין אנשי קשר עם מספר טלפון';

  @override
  String get backUpCallHistory => 'גיבוי היסטוריית השיחות';

  @override
  String get backUpCallHistoryBody =>
      'מוצפן מקצה לקצה בחשבון שלך, כך שטלפון חדש יכול לשחזר אותו. רק את/ה יכול/ה לקרוא אותו.';

  @override
  String backedUpCalls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'גובו $count שיחות',
      one: 'גובתה שיחה אחת',
    );
    return '$_temp0';
  }

  @override
  String get backupDeleted => 'הגיבוי כובה ונמחק';

  @override
  String get backUpNow => 'גיבוי עכשיו';

  @override
  String get alreadyUpToDate => 'כבר מעודכן';

  @override
  String get restoreToPhone => 'שחזור לטלפון הזה';

  @override
  String get restoreToPhoneBody =>
      'מוסיף שיחות מגובות שחסרות בהיסטוריה של הטלפון הזה';

  @override
  String get nothingToRestore => 'אין מה לשחזר';

  @override
  String restoredCalls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'שוחזרו $count שיחות',
      one: 'שוחזרה שיחה אחת',
    );
    return '$_temp0';
  }

  @override
  String get backupExplain =>
      'הגיבוי פועל לפי \"שמירת היסטוריית השיחות\": שיחות ישנות יותר נמחקות גם ממנו. מחיקת שיחה בשיחות האחרונות מוחקת גם את הגיבוי שלה.';

  @override
  String get unknownCallersHeader => 'שיחות ממספרים שאינם באנשי הקשר';

  @override
  String get blockHidden => 'חסימת מספרים חסויים';

  @override
  String get blockHiddenBody => 'שיחות עם זיהוי חסוי או לא ידוע';

  @override
  String get blockedPrefixes => 'קידומות ומדינות חסומות';

  @override
  String get blockedPrefixesBody =>
      'חסימת כל מספר שמתחיל, למשל, ב-‎+1900 או מדינה שלמה כמו ‎+44';

  @override
  String get addPrefix => 'הוספת קידומת';

  @override
  String removePrefix(String prefix) {
    return 'הסרת $prefix';
  }

  @override
  String get protectionExplain =>
      'אנשי קשר שחסמת או שהעברת לתא הקולי ב-ZT Contacts מטופלים גם כאן. הכללים פועלים גם כש-ZT Phone נעולה, ואנשי הקשר שלך תמיד מצלצלים אלא אם העברת אותם לתא הקולי.';

  @override
  String get blockStartingWith => 'חסימת מספרים שמתחילים ב-';

  @override
  String get unknownRing => 'צלצול כרגיל';

  @override
  String get unknownSilence => 'השתקה (עדיין מופיעים בשיחות האחרונות)';

  @override
  String get unknownVoicemail => 'העברה לתא הקולי';

  @override
  String couldntOpenContacts(String reason) {
    return 'לא ניתן היה לפתוח את אנשי הקשר. $reason';
  }

  @override
  String noContactsMatch(String query) {
    return 'אין אנשי קשר שתואמים ל-\"$query\"';
  }

  @override
  String get noFavoritesContacts =>
      'עדיין אין מועדפים.\nאנשי קשר שמסמנים בכוכב ב-ZT Contacts מופיעים כאן.';

  @override
  String get contactsComeFrom =>
      'אנשי הקשר שלך מגיעים מ-ZT Contacts, מוצפנים מקצה לקצה עם אותו חשבון. אנשי קשר שמוסיפים שם מופיעים כאן.';

  @override
  String get getZtContacts => 'להורדת ZT Contacts';

  @override
  String get deleteThisHistory => 'מחיקת ההיסטוריה הזו';

  @override
  String get message => 'הודעה';

  @override
  String get callSettings => 'הגדרות שיחה';

  @override
  String get noCallsInHistory => 'אין שיחות בהיסטוריה של הטלפון הזה.';

  @override
  String dayAndTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String deleteCallsQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'למחוק $count שיחות מההיסטוריה?',
      one: 'למחוק שיחה אחת מההיסטוריה?',
    );
    return '$_temp0';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds שנ׳';
  }

  @override
  String get incoming => 'נכנסת';

  @override
  String get outgoing => 'יוצאת';

  @override
  String get missed => 'שלא נענתה';

  @override
  String get declined => 'נדחתה';

  @override
  String get blocked => 'חסומה';

  @override
  String get noFavoritesFrequent =>
      'עדיין אין מועדפים.\nאנשי קשר שמסמנים בכוכב ב-ZT Contacts מופיעים כאן, יחד עם האנשים שמתקשרים אליהם הכי הרבה.';

  @override
  String get frequent => 'תכופים';

  @override
  String get searchCalls => 'חיפוש שיחות';

  @override
  String get searchContacts => 'חיפוש אנשי קשר';

  @override
  String get clearSearch => 'ניקוי החיפוש';

  @override
  String get settings => 'הגדרות';

  @override
  String get dialpad => 'חייגן';

  @override
  String get favorites => 'מועדפים';

  @override
  String get recents => 'אחרונות';

  @override
  String get contacts => 'אנשי קשר';

  @override
  String get callAlertsOff =>
      'שיחות נכנסות לא יכולות להופיע במסך הנעילה או כהתראה. צריך לאשר התראות שיחה עבור ZT Phone.';

  @override
  String get allow => 'אישור';

  @override
  String get makeDefault =>
      'אפשר להגדיר את ZT Phone כאפליקציית הטלפון כדי לענות לשיחות כאן, לראות את היסטוריית השיחות ולחסום מספרים.';

  @override
  String get setAsDefault => 'הגדרה כברירת מחדל';

  @override
  String get ringtone => 'רינגטון';

  @override
  String get phoneRingtone => 'הרינגטון של הטלפון';

  @override
  String get custom => 'מותאם';

  @override
  String get sendToVoicemail => 'העברת שיחות לתא הקולי';

  @override
  String get sendToVoicemailBody =>
      'השיחות שלהם לא מצלצלות; הם יכולים להשאיר הודעה';

  @override
  String get callWith => 'חיוג עם';

  @override
  String get askOrDefault => 'לשאול או להשתמש בברירת המחדל';

  @override
  String get callSettingsExplain =>
      'נשמר מוצפן בחשבון שלך, כך שגם טלפון חדש יקבל אותן. ההגדרות פועלות גם כש-ZT Phone נעולה; לשם כך הטלפון שומר רק צורה מעורבלת של המספרים.';

  @override
  String get filterAll => 'הכול';

  @override
  String couldntReadHistory(String reason) {
    return 'לא ניתן היה לקרוא את היסטוריית השיחות.\n$reason';
  }

  @override
  String noCallsMatch(String query) {
    return 'אין שיחות שתואמות ל-\"$query\"';
  }

  @override
  String get noCallsYet =>
      'עדיין אין שיחות.\nשיחות יוצאות ונכנסות מופיעות כאן.';

  @override
  String get noMissedCalls => 'אין שיחות שלא נענו';

  @override
  String get noIncomingCalls => 'אין שיחות נכנסות';

  @override
  String get noOutgoingCalls => 'אין שיחות יוצאות';

  @override
  String get noBlockedCalls => 'אין שיחות חסומות';

  @override
  String get deleteThisCall => 'למחוק את השיחה הזו מההיסטוריה?';

  @override
  String noSpeedDialOn(String digit) {
    return 'אין חיוג מהיר במקש $digit';
  }

  @override
  String get pickContactForKey =>
      'אפשר לבחור איש קשר לחיוג בלחיצה ארוכה על המקש הזה.';

  @override
  String get pickContact => 'בחירת איש קשר';

  @override
  String get keyZeroHold => '0, לחיצה ארוכה לפלוס';

  @override
  String get keyOneHold => '1, לחיצה ארוכה לתא הקולי';

  @override
  String get nativePrivateNumber => 'מספר חסוי';

  @override
  String get nativeMissedCall => 'שיחה שלא נענתה';

  @override
  String get nativeMissedCalls => '%d שיחות שלא נענו';

  @override
  String get nativeLatestFrom => 'האחרונה מ-%s';

  @override
  String get nativeCallBack => 'חיוג חוזר';

  @override
  String get nativeNewVoicemail => 'הודעה קולית חדשה';

  @override
  String get nativeVoicemailMessages =>
      '%d הודעות. אפשר להקיש כדי לחייג לתא הקולי';

  @override
  String get nativeTapToCallVoicemail => 'אפשר להקיש כדי לחייג לתא הקולי';

  @override
  String get nativeCallVoicemail => 'חיוג לתא הקולי';

  @override
  String get nativeMissedChannel => 'שיחות שלא נענו';

  @override
  String get nativeIncomingChannel => 'שיחות נכנסות';

  @override
  String get nativeOngoingChannel => 'שיחות פעילות';

  @override
  String get nativeOngoingCall => 'שיחה פעילה';

  @override
  String get nativeHangUp => 'ניתוק';

  @override
  String get replyCantTalk => 'לא יכול/ה לדבר עכשיו. אחזור אליך.';

  @override
  String get replyDriving => 'אני נוהג/ת. אתקשר בקרוב.';

  @override
  String get replyMeeting => 'אני בפגישה. אפשר לשלוח הודעה?';

  @override
  String get replyOnMyWay => 'בדרך.';

  @override
  String get accept => 'אישור';

  @override
  String get rtt => 'RTT';

  @override
  String get video => 'וידאו';

  @override
  String get videoCall => 'שיחת וידאו';

  @override
  String get incomingVideoCall => 'שיחת וידאו נכנסת';

  @override
  String get answerVoice => 'קולית';

  @override
  String get answerVideo => 'וידאו';

  @override
  String get rttRequestBody => 'הצד השני רוצה לעבור לטקסט בזמן אמת (RTT).';

  @override
  String get videoRequestBody => 'הצד השני רוצה לעבור לווידאו.';

  @override
  String get rttFailed => 'טקסט בזמן אמת לא זמין בשיחה הזו.';

  @override
  String get videoFailed =>
      'לא ניתן להפעיל וידאו. ייתכן שהספק לא מאפשר זאת בשיחה הזו.';

  @override
  String get rttHint =>
      'אפשר לדבר בהקלדה. הצד השני רואה כל אות ברגע שמקלידים אותה, והמילים שלו מופיעות כאן תוך כדי הקלדה.';

  @override
  String get rttTypeHere => 'כתיבת הודעה';

  @override
  String get rttSeesTyping => 'נשלח תוך כדי הקלדה';

  @override
  String get rttYouSaid => 'אני';

  @override
  String get rttTheySaid => 'הצד השני';

  @override
  String get waitingForVideo => 'ממתין לווידאו';

  @override
  String get cameraOff => 'כיבוי מצלמה';

  @override
  String get cameraOn => 'הפעלת מצלמה';

  @override
  String get switchCamera => 'החלפה';

  @override
  String get voiceOnly => 'קול בלבד';

  @override
  String get callAccessibility => 'נגישות ווידאו';

  @override
  String get callAccessibilityBody => 'טקסט בזמן אמת (RTT), TTY ושיחות וידאו';

  @override
  String get startWithRtt => 'התחלת שיחות עם טקסט בזמן אמת';

  @override
  String get startWithRttBody =>
      'הקלדה וקריאה במהלך שיחות, לצד דיבור או במקומו. הצד השני רואה כל אות ברגע שמקלידים אותה. אפשר גם להפעיל RTT במהלך כל שיחה שתומכת בכך.';

  @override
  String get rttAvailable => 'הספק שלך מציע RTT בטלפון הזה';

  @override
  String get rttNotAvailable => 'RTT לא זמין בטלפון הזה כרגע';

  @override
  String get rttNotAvailableBody =>
      'RTT דורש תמיכה של הספק. בטלפונים רבים צריך גם להפעיל RTT בהגדרות הנגישות של Android, דרך \"מצב TTY והגדרות RTT\" למטה.';

  @override
  String get videoCalling => 'שיחות וידאו דרך הספק';

  @override
  String get videoAvailable =>
      'זמין. אפשר ללחוץ על כפתור הווידאו בזמן חיוג, או להפעיל וידאו במהלך שיחה.';

  @override
  String get videoNotAvailable =>
      'לא זמין כרגע. שיחות וידאו דורשות VoLTE ושיחות וידאו מהספק, ולפעמים צריך להפעיל אותן בהגדרות ה-SIM של Android.';

  @override
  String get ttySettings => 'מצב TTY והגדרות RTT';

  @override
  String get ttySettingsBody =>
      'פתיחת הגדרות הנגישות לשיחות של אפליקציית הטלפון המובנית. Android מאפשר רק לאפליקציית הטלפון המובנית לשנות את מצב TTY.';

  @override
  String get ttySettingsMissing =>
      'אין בטלפון הזה מסך מובנה למצב TTY, ו-Android לא מאפשר לאפליקציות אחרות לשנות אותו.';

  @override
  String get callAccessibilityPrivacy =>
      'טקסט בזמן אמת ווידאו עוברים ברשת של הספק, ישירות לצד השני. ZT Phone אף פעם לא שולח אותם לשרתים שלו ולא שומר אותם אחרי השיחה.';

  @override
  String get pasteNumber => 'הדבקת מספר';

  @override
  String get noNumberInText => 'לא נמצא מספר טלפון בטקסט שהועתק';

  @override
  String get whichNumber => 'איזה מספר?';

  @override
  String get dialWithPauses => 'חיוג עם השהיות';

  @override
  String get dialWithPausesShort => 'המתנה, ואז שליחת קוד או בחירה בתפריט';

  @override
  String get dialWithPausesExplain =>
      'לתפריטים טלפוניים, קודי שיחת ועידה וקוד לתא קולי: מחייגים, ממתינים, ואז שולחים את הספרות בשבילך. שומרים, ובפעם הבאה זו לחיצה אחת.';

  @override
  String get dialShortcutDefaultLabel => 'שיחה עם קוד';

  @override
  String get dialShortcutName => 'שם';

  @override
  String get dialShortcutNameHint => 'קוד תא קולי, ועידה בעבודה…';

  @override
  String get numberToCall => 'מספר לחיוג';

  @override
  String get addPause => 'המתנה של 3 שניות';

  @override
  String get addWaitForTap => 'המתנה ללחיצה שלי';

  @override
  String get addTones => 'שליחת ספרות';

  @override
  String get dialsAs => 'מחייג';

  @override
  String get callNow => 'חיוג עכשיו';

  @override
  String pauseSeconds(int seconds) {
    return 'המתנה של כ-$seconds שניות';
  }

  @override
  String get shorterPause => 'קצר יותר';

  @override
  String get longerPause => 'ארוך יותר';

  @override
  String get waitForTapStep => 'המתנה עד שאלחץ על \'שליחה\' במסך השיחה';

  @override
  String get tonesToSend => 'ספרות לשליחה';

  @override
  String get removeStep => 'הסרת שלב';

  @override
  String get edit => 'עריכה';

  @override
  String get hideMyNumber => 'הסתרת המספר שלי בשיחה הזו';

  @override
  String get showMyNumber => 'הצגת המספר שלי בשיחה הזו';

  @override
  String get numberHidden => 'המספר שלי מוסתר';

  @override
  String get keyStarHold => 'כוכבית, לחיצה ארוכה להשהיה';

  @override
  String get keyHashHold => 'סולמית, לחיצה ארוכה להמתנה';

  @override
  String get callWithNumberHidden => 'חיוג עם מספר מוסתר';

  @override
  String get callWithNumberHiddenBody =>
      'יופיע אצלם \"מספר חסוי\", אם הספק שלך מאפשר. מספרי חירום תמיד רואים את המספר שלך.';

  @override
  String get hideMyNumberForContact => 'הסתרת המספר שלי';

  @override
  String get hideMyNumberForContactBody =>
      'כל שיחה לאיש הקשר הזה תופיע כ\"מספר חסוי\", אם הספק שלך מאפשר. מספרי חירום תמיד רואים את המספר שלך.';

  @override
  String timeTomorrow(String time) {
    return '$time מחר';
  }

  @override
  String timeYesterday(String time) {
    return '$time אתמול';
  }

  @override
  String timeRange(String from, String to) {
    return '$from–$to';
  }

  @override
  String countryTimeThere(String country, String time) {
    return '$country · שם עכשיו $time';
  }

  @override
  String sendTonesQuestion(String tones) {
    return 'לשלוח עכשיו $tones?';
  }

  @override
  String get skip => 'דילוג';

  @override
  String get privateCallLog => 'יומן שיחות פרטי';

  @override
  String get privateCallLogBody =>
      'שיחות עם איש הקשר הזה נשמרות רק בכספת המוצפנת שלך, ולא בהיסטוריית השיחות המשותפת של Android שאפליקציות אחרות יכולות לקרוא. הספק שלך עדיין שומר רישום משלו.';

  @override
  String movedToVault(int count) {
    return '$count שיחות קודמות הועברו לכספת';
  }

  @override
  String get callStats => 'סטטיסטיקת שיחות';

  @override
  String get statsWeek => '7 ימים';

  @override
  String get statsMonth => '30 יום';

  @override
  String get statsYear => 'שנה';

  @override
  String get statsCalls => 'שיחות';

  @override
  String statsInOut(int incoming, int outgoing) {
    return '$incoming נכנסות · $outgoing יוצאות';
  }

  @override
  String get statsTalkTime => 'זמן דיבור';

  @override
  String get statsAverageCall => 'שיחה ממוצעת';

  @override
  String get statsLastWeeks => '8 השבועות האחרונים';

  @override
  String get statsMostTalked => 'עם מי דיברת הכי הרבה';

  @override
  String statsPersonLine(int calls, String talk) {
    return '$calls שיחות · $talk';
  }

  @override
  String statsWeekBar(String start, int calls, String talk) {
    return 'השבוע של $start: $calls שיחות, $talk';
  }

  @override
  String get statsPrivacy =>
      'מחושב בטלפון הזה מתוך היסטוריית השיחות שלך. שום דבר לא נשלח לשום מקום.';

  @override
  String talkMinutes(int minutes) {
    return '$minutes דק׳';
  }

  @override
  String talkHoursMinutes(int hours, int minutes) {
    return '$hours שע׳ $minutes דק׳';
  }

  @override
  String remindMeToCallBack(String name) {
    return 'תזכורת לחזור אל $name';
  }

  @override
  String get remindMeToCallBackShort => 'תזכורת לחזור בשיחה';

  @override
  String get remindMeToCallBackBody => 'תזכורת כאן, ומשימה ב-ZT Tasks';

  @override
  String get callBackLater => 'לחזור מאוחר יותר';

  @override
  String get in15Minutes => 'בעוד 15 דקות';

  @override
  String get in1Hour => 'בעוד שעה';

  @override
  String get in3Hours => 'בעוד 3 שעות';

  @override
  String get tonight => 'הערב';

  @override
  String get tomorrowMorning => 'מחר בבוקר';

  @override
  String get pickATime => 'בחירת תאריך ושעה';

  @override
  String get callBackExplain =>
      'ZT Phone יזכיר לך בזמן הזה ויוסיף משימה ל-ZT Tasks. שתיהן מסתיימות ברגע שחוזרים בשיחה.';

  @override
  String callBackSetWithTask(String time) {
    return 'אזכיר לך ב-$time. נוסף ל-ZT Tasks.';
  }

  @override
  String callBackSetNoTask(String time) {
    return 'אזכיר לך ב-$time. לא הצלחתי להגיע ל-ZT Tasks, ולכן לא נוספה משימה.';
  }

  @override
  String callBackTaskTitle(String name) {
    return 'לחזור אל $name';
  }

  @override
  String callBackName(String name) {
    return 'לחזור אל $name';
  }

  @override
  String callBackDue(String time) {
    return 'היה אמור ב-$time';
  }

  @override
  String get cancelReminder => 'ביטול התזכורת';

  @override
  String get nativeCallBackReminder => 'לחזור אל %s';

  @override
  String get nativeCallBackChannel => 'תזכורות לחזור בשיחה';

  @override
  String get nativeRemindMe => 'תזכורת';

  @override
  String get numberHiddenNotice =>
      'המספר שלך מוסתר בשיחה הזו אם הספק שלך מאפשר. מספרי חירום תמיד רואים אותו.';

  @override
  String get privateLogLimitsTitle => 'לפני שמפעילים';

  @override
  String get privateLogLimitsIntro =>
      'ZT Phone מעביר את השיחות האלה לכספת שלך, אבל Android לא מאפשר לאף אפליקציית טלפון למנוע לגמרי את רישום השיחה בהיסטוריה המשותפת:';

  @override
  String get privateLogLimitSeconds =>
      'כל שיחה מופיעה בהיסטוריה המשותפת של Android לכמה שניות אחרי שהיא מסתיימת, עד ש-ZT Phone מעביר אותה.';

  @override
  String get privateLogLimitDefault =>
      'אם ZT Phone אינו אפליקציית הטלפון שמוגדרת כברירת מחדל, השיחות נשארות שם עד הפעם הבאה שפותחים את ZT Phone.';

  @override
  String get privateLogLimitCarrier =>
      'הרישומים והחשבון של הספק שלך עדיין מציגים כל שיחה.';

  @override
  String get turnOn => 'הפעלה';

  @override
  String get notNow => 'לא עכשיו';

  @override
  String get exactRemindersTitle => 'להזכיר בדיוק בזמן?';

  @override
  String get exactRemindersBody =>
      'Android מאפשר ל-ZT Phone להזכיר בדיוק בדקה שבחרת רק אם מאשרים לו \"שעונים מעוררים ותזכורות\". בלי זה התזכורות עדיין מגיעות, אבל יכולות לאחר בכמה דקות.';

  @override
  String get callBackMayBeLate => 'תזכורות יכולות לאחר בכמה דקות';

  @override
  String get callBackMayBeLateBody =>
      'יש להקיש כדי לאשר \"שעונים מעוררים ותזכורות\" לזמנים מדויקים';

  @override
  String get returnToCall => 'חזרה לשיחה';

  @override
  String get rememberSimForNumber => 'לזכור עבור המספר הזה';

  @override
  String get rememberSimForNumberBody => 'בפעם הבאה ייבחר ה-SIM הזה בלי לשאול';

  @override
  String get callHoldForSim => 'חיוג (לחיצה ארוכה לבחירת SIM)';

  @override
  String get simPerNumber => 'SIM לכל מספר';

  @override
  String get simPerNumberShort => 'מספרים שתמיד מחויגים מאותו SIM';

  @override
  String get simPerNumberBody =>
      'בטלפון עם שני כרטיסי SIM, ZT Phone שואל באיזה מהם להשתמש, אלא אם נבחר באנדרואיד SIM ברירת מחדל לשיחות. אם מסמנים \"לזכור עבור המספר הזה\" בשאלה, המספר תמיד יחויג מאותו SIM. לחיצה ארוכה על כפתור החיוג מאפשרת לבחור מחדש. SIM שנקבע לאיש קשר תמיד גובר.';

  @override
  String get simPerNumberEmpty => 'אין עדיין מספרים';

  @override
  String get forget => 'לשכוח';

  @override
  String get keypadAndHandling => 'מקלדת ואחיזה';

  @override
  String get keypadAndHandlingBody =>
      'מקשים גדולים, מצב יד אחת, צלילי מקשים, הפיכה להשתקה';

  @override
  String get largeKeys => 'מקשים גדולים';

  @override
  String get largeKeysBody => 'מקשים וספרות גדולים יותר במקלדת החיוג';

  @override
  String get oneHandedMode => 'מצב יד אחת';

  @override
  String get oneHandedModeBody =>
      'מקלדת צרה יותר בצד אחד, בהישג האגודל. החץ שלידה מעביר אותה לצד השני.';

  @override
  String get handLeft => 'שמאל';

  @override
  String get handRight => 'ימין';

  @override
  String get keypadMoveLeft => 'העברת המקלדת שמאלה';

  @override
  String get keypadMoveRight => 'העברת המקלדת ימינה';

  @override
  String get keyTones => 'צלילי מקשים';

  @override
  String get keyTonesBody =>
      'צליל קצר לכל מקש, בעוצמת צלילי המקלדת של הטלפון. שקט כשהטלפון במצב שקט.';

  @override
  String get keyVibration => 'רטט מקשים';

  @override
  String get vibrationLight => 'קל';

  @override
  String get vibrationStrong => 'חזק';

  @override
  String get handling => 'אחיזה';

  @override
  String get flipToSilence => 'הפיכה להשתקה';

  @override
  String get flipToSilenceBody =>
      'הפיכת טלפון מצלצל עם המסך למטה משתיקה את השיחה. המתקשר ממשיך לשמוע צלצול, ועדיין אפשר לענות.';

  @override
  String get pocketGuard => 'הגנה מחיוג בכיס';

  @override
  String get pocketGuardBody =>
      'לא לחייג כשמשהו מכסה את המסך, כמו כיס או תיק. דורש חיישן קרבה.';

  @override
  String get pocketGuardStopped =>
      'השיחה לא חויגה: נראה שהמסך מכוסה. אם זו טעות, אפשר לכבות את ההגנה מחיוג בכיס בהגדרות.';

  @override
  String get inMeetingDefaultMessage => 'אני בפגישה, אחזור אליך בקרוב.';

  @override
  String get meetingUntitled => 'פגישה';

  @override
  String meetingNow(String title) {
    return 'עכשיו: $title';
  }

  @override
  String meetingToday(String time) {
    return 'היום $time';
  }

  @override
  String meetingTomorrow(String time) {
    return 'מחר $time';
  }

  @override
  String meetingAt(String when, String title) {
    return '$when: $title';
  }

  @override
  String get callTools => 'עוד';

  @override
  String get callNote => 'כתיבת פתק';

  @override
  String get callNoteBody => 'נשמר ב-ZT Notes';

  @override
  String callNoteTitle(String name) {
    return 'שיחה עם $name';
  }

  @override
  String get callNoteHint => 'מה לזכור מהשיחה';

  @override
  String get callNoteWhere =>
      'נשמר מוצפן בטלפון, ועובר ל-ZT Notes בפעם הבאה שפותחים את ZT Phone.';

  @override
  String get callNoteSaved =>
      'הפתק נשמר. הוא יעבור ל-ZT Notes כשתפתחו את ZT Phone.';

  @override
  String get textMyCard => 'שליחת הכרטיס שלי בהודעה';

  @override
  String get textMyCardBody =>
      'פותח את אפליקציית ההודעות עם השם והמספר שלך, מוכן לשליחה';

  @override
  String get myCardNotSet =>
      'קודם צריך להגדיר את הכרטיס שלך בהגדרות של ZT Phone';

  @override
  String get openCalendar => 'פתיחת ZT Calendar';

  @override
  String get openCalendarBody => 'לבדוק את היומנים המשותפים. השיחה ממשיכה.';

  @override
  String get calendarMissing => 'ZT Calendar לא מותקן';

  @override
  String get calendarAndCalls => 'יומן ושיחות';

  @override
  String get calendarAndCallsShort => 'פגישות בשיחות, ושיחות בזמן פגישות';

  @override
  String get calendarAndCallsBody =>
      'ZT Phone קורא את ZT Calendar באותו חשבון, בטלפון הזה בלבד, כדי לדעת מתי יש לך פגישות ועם מי.';

  @override
  String get showMeetings => 'הצגת פגישות עם איש קשר';

  @override
  String get showMeetingsBody =>
      '\"מחר 10:00: סקירת עיצוב\" בשיחות שלהם ובכרטיס איש הקשר';

  @override
  String get callsDuringMeetings => 'שיחות בזמן פגישה';

  @override
  String get inMeetingRing => 'צלצול רגיל';

  @override
  String get inMeetingSilence => 'צלצול שקט';

  @override
  String get inMeetingSilenceBody => 'השיחה מוצגת, בלי צליל';

  @override
  String get inMeetingDecline => 'דחייה עם הודעה';

  @override
  String get inMeetingDeclineBody =>
      'המתקשר מקבל את ההודעה שלך; השיחה מופיעה באחרונות';

  @override
  String get inMeetingMessage => 'הודעה';

  @override
  String get letRepeatCallersRing => 'לתת למתקשרים חוזרים לצלצל';

  @override
  String get letRepeatCallersRingBody =>
      'שיחה שנייה מאותו מספר תוך 15 דקות תצלצל כרגיל, למקרה שזה דחוף';

  @override
  String get calendarAndCallsLimits =>
      'נספרים אירועים עם שעה ב-ZT Calendar שלך ל-7 הימים הקרובים; אירועים של יום שלם לא נספרים. הזמנים מתעדכנים בכל פתיחה של ZT Phone, ונשמרים בטלפון רק זמני התחלה וסיום.';

  @override
  String get myCard => 'הכרטיס שלי';

  @override
  String get myCardShort => 'מה נשלח ב\"שליחת הכרטיס שלי\" בזמן שיחה';

  @override
  String get myCardBody =>
      'בזמן שיחה, \"שליחת הכרטיס שלי\" פותח את אפליקציית ההודעות עם הטקסט הזה לצד השני, מוכן לשליחה. הוא נשמר מוצפן בטלפון כדי לעבוד גם כש-ZT Phone נעול.';

  @override
  String get myCardPick => 'בחירה מ-ZT Contacts';

  @override
  String get myCardText => 'טקסט הכרטיס';

  @override
  String get homeScreenWidget => 'ווידג\'ט למסך הבית';

  @override
  String get widgetDetails => 'הצגת פרטים במסך הבית';

  @override
  String get widgetDetailsBody =>
      'כבוי: הווידג\'ט של השיחות האחרונות מציג מנעול ואת מספר השיחות החדשות שלא נענו. מופעל: הווידג\'ט מציג את השיחות האחרונות, ושמות אנשי הקשר שלך מ-ZT Contacts נשמרים בטלפון הזה ללא הצפנה, בשביל מסך הבית. אנשי קשר פרטיים אף פעם לא מוצגים';

  @override
  String get widgetRecents => 'שיחות אחרונות';

  @override
  String get widgetMissed => 'שיחות שלא נענו';

  @override
  String get widgetSwitchView => 'מעבר בין שיחות אחרונות לשיחות שלא נענו';

  @override
  String get widgetDialpad => 'לוח חיוג';

  @override
  String get widgetNoCalls => 'אין עדיין שיחות';

  @override
  String get widgetNoMissed => 'אין שיחות שלא נענו';

  @override
  String get widgetOpenToAllow =>
      'יש לפתוח את ZT Phone כדי לאשר גישה ליומן השיחות';

  @override
  String get widgetRecentsHidden =>
      'כדי לראות כאן את השיחות, יש להפעיל את \"הצגת פרטים במסך הבית\" בהגדרות של ZT Phone';

  @override
  String get widgetYesterday => 'אתמול';

  @override
  String get spamHeader => 'מספרים שדווחו כספאם';

  @override
  String get spamOff => 'כבוי (בלי להוריד את הרשימה)';

  @override
  String get spamWarn => 'צלצול, עם אזהרה במסך השיחה';

  @override
  String get spamSilence => 'השתקה (עדיין מופיעים בשיחות האחרונות)';

  @override
  String get spamVoicemail => 'העברה לתא הקולי';

  @override
  String get spamExplain =>
      'פעם בשבוע ZT Phone מורידה רשימה של מספרים שאנשים רבים דיווחו עליהם כספאם, מהגרסאות של ZT Phone עצמה ב-GitHub, ומשתמשת בה רק אם החתימה שלה תקינה. הבדיקה של המספרים נעשית בטלפון הזה: שום דבר עליך או על השיחות שלך לא נשלח. אנשי הקשר שלך אף פעם לא מושפעים. מקורות: תלונות למאגר Do Not Call האמריקאי (FTC) ומספרים שדווחו ל-ZT Phone.';

  @override
  String spamListInfo(String date, int count) {
    return 'רשימה מ-$date, $count מספרים';
  }

  @override
  String get spamListNone => 'עדיין לא הורדה רשימה';

  @override
  String get spamCheckNow => 'בדיקה אם יש רשימה חדשה יותר';

  @override
  String get spamUpdated => 'רשימת הספאם עודכנה';

  @override
  String get spamUpToDate => 'רשימת הספאם מעודכנת';

  @override
  String get spamCheckFailed =>
      'לא הצלחנו להוריד את רשימת הספאם. כדאי לבדוק את החיבור ולנסות שוב';

  @override
  String reportedSpam(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'דווח כספאם $count פעמים',
      one: 'דווח כספאם',
    );
    return '$_temp0';
  }
}
