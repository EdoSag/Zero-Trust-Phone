import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';

/// What the Android side needs to screen calls and ring while the vault
/// is locked, built from the unlocked address book and Phone's settings.
class ScreeningRules {
  const ScreeningRules({
    required this.unknownMode,
    required this.blockHidden,
    required this.prefixes,
    required this.contactKeys,
    required this.voicemailKeys,
    required this.ringtones,
  });

  factory ScreeningRules.build({
    required List<PhoneContact> contacts,
    required List<ContactCallSettings> settings,
    required CallProtection protection,
  }) {
    final Map<String, ContactCallSettings> byContact =
        <String, ContactCallSettings>{
          for (final ContactCallSettings s in settings) s.contactId: s,
        };
    final Set<String> contactKeys = <String>{};
    final Set<String> voicemailKeys = <String>{};
    final Map<String, String> ringtones = <String, String>{};
    for (final PhoneContact c in contacts) {
      final ContactCallSettings? s = byContact[c.id];
      for (final String p in c.phones) {
        final String key = PhoneNumbers.lookupKey(p);
        if (key.isEmpty) continue;
        contactKeys.add(key);
        // A contact blocked in ZT Contacts goes to voicemail too.
        if (s?.toVoicemail == true || c.isBlocked) voicemailKeys.add(key);
        final String? tone = s?.ringtone;
        if (tone != null && tone.isNotEmpty) ringtones[key] = tone;
      }
    }
    return ScreeningRules(
      unknownMode: protection.unknownCallers.name,
      blockHidden: protection.blockHidden,
      prefixes: protection.blockedPrefixes,
      contactKeys: contactKeys.toList()..sort(),
      voicemailKeys: voicemailKeys.toList()..sort(),
      ringtones: ringtones,
    );
  }

  final String unknownMode;
  final bool blockHidden;
  final List<String> prefixes;
  final List<String> contactKeys;
  final List<String> voicemailKeys;
  final Map<String, String> ringtones;

  /// Same rules as [other], so there's nothing to send again.
  bool same(ScreeningRules? other) =>
      other != null &&
      other.unknownMode == unknownMode &&
      other.blockHidden == blockHidden &&
      other.prefixes.join('|') == prefixes.join('|') &&
      other.contactKeys.join('|') == contactKeys.join('|') &&
      other.voicemailKeys.join('|') == voicemailKeys.join('|') &&
      other.ringtones.toString() == ringtones.toString();
}

/// How on-device screening treats a call, mirrored from
/// ZtCallScreeningService.decide for tests and the settings preview.
enum ScreeningDecision { allow, silence, voicemail, block }

ScreeningDecision decideCall(
  ScreeningRules rules, {
  required String number,
  bool hidden = false,
}) {
  ScreeningDecision unknown() => switch (rules.unknownMode) {
    'silence' => ScreeningDecision.silence,
    'voicemail' => ScreeningDecision.voicemail,
    _ => ScreeningDecision.allow,
  };
  if (hidden || number.trim().isEmpty) {
    return rules.blockHidden ? ScreeningDecision.block : unknown();
  }
  if (rules.prefixes.any((String p) => prefixMatches(number, p))) {
    return ScreeningDecision.block;
  }
  final String key = PhoneNumbers.lookupKey(number);
  if (rules.contactKeys.contains(key)) {
    return rules.voicemailKeys.contains(key)
        ? ScreeningDecision.voicemail
        : ScreeningDecision.allow;
  }
  return unknown();
}

/// "+44" also matches "0044...". Same as PhoneNumbersPrefix.matches.
bool prefixMatches(String number, String prefix) {
  final String p = PhoneNumbers.normalize(prefix);
  if (p.isEmpty) return false;
  final String n = PhoneNumbers.normalize(number);
  if (n.startsWith(p)) return true;
  return p.startsWith('+') && n.startsWith('00${p.substring(1)}');
}
