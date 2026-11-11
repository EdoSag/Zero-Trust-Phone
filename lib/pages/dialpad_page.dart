import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/pages/call_actions.dart';
import 'package:zerotrust_phone/pages/speed_dial_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// The keypad. Typing digits also finds contacts by name (T9) or number.
class DialpadPage extends ConsumerStatefulWidget {
  const DialpadPage({super.key, this.initialNumber = ''});

  final String initialNumber;

  @override
  ConsumerState<DialpadPage> createState() => _DialpadPageState();
}

class _DialpadPageState extends ConsumerState<DialpadPage> {
  late final TextEditingController _number = TextEditingController(
    text: widget.initialNumber,
  );

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _type(String key) {
    HapticFeedback.selectionClick();
    final TextSelection sel = _number.selection;
    final String text = _number.text;
    final int start = sel.isValid ? sel.start : text.length;
    final int end = sel.isValid ? sel.end : text.length;
    setState(() {
      _number.value = TextEditingValue(
        text: text.replaceRange(start, end, key),
        selection: TextSelection.collapsed(offset: start + key.length),
      );
    });
  }

  void _backspace() {
    final String text = _number.text;
    if (text.isEmpty) return;
    final TextSelection sel = _number.selection;
    int start = sel.isValid ? sel.start : text.length;
    final int end = sel.isValid ? sel.end : text.length;
    if (start == end) {
      if (start == 0) return;
      start -= 1;
    }
    setState(() {
      _number.value = TextEditingValue(
        text: text.replaceRange(start, end, ''),
        selection: TextSelection.collapsed(offset: start),
      );
    });
  }

  /// Long-press 1 calls voicemail (P5); 2 to 9 are speed dial (P8).
  Future<void> _longPress(String digit) async {
    HapticFeedback.heavyImpact();
    if (digit == '1') {
      await ref.read(telecomProvider).callVoicemail();
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    final int n = int.parse(digit);
    final SpeedDial? dial =
        (ref.read(speedDialsProvider).value ?? const <SpeedDial>[])
            .where((SpeedDial s) => s.digit == n)
            .firstOrNull;
    if (dial != null) {
      await placeCall(ref, dial.number);
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    if (!mounted) return;
    final bool? assign = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text(d.l10n.noSpeedDialOn(digit)),
        content: Text(d.l10n.pickContactForKey),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: Text(d.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(d.l10n.pickContact),
          ),
        ],
      ),
    );
    if (assign == true && mounted) await assignSpeedDial(context, ref, n);
  }

  Future<void> _call(String number) async {
    if (number.trim().isEmpty) {
      // Like other dialers: an empty call button brings back the last number.
      final List<CallLogEntry> log =
          ref.read(callLogProvider).value ?? const <CallLogEntry>[];
      final CallLogEntry? last = log
          .where((CallLogEntry e) => e.type == CallType.outgoing)
          .firstOrNull;
      if (last != null) setState(() => _number.text = last.number);
      return;
    }
    await placeCall(ref, number.trim());
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final String digits = _number.text.replaceAll(RegExp(r'[^0-9]'), '');
    final List<PhoneContact> contacts =
        ref.watch(phoneContactsProvider).value ?? const <PhoneContact>[];
    final List<PhoneContact> matches = digits.isEmpty
        ? const <PhoneContact>[]
        : contacts
              .where(
                (PhoneContact c) =>
                    PhoneNumbers.t9Matches(c.name, digits) ||
                    c.phones.any(
                      (String p) => PhoneNumbers.normalize(p).contains(digits),
                    ),
              )
              .take(20)
              .toList();
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                children: <Widget>[
                  for (final PhoneContact c in matches)
                    for (final String p in c.phones)
                      ListTile(
                        leading: ContactAvatar(label: c.name),
                        title: Text(c.name),
                        subtitle: Text(ltr(p)),
                        onTap: () => _call(p),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _number,
                      readOnly: true,
                      showCursor: true,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      // Numbers read left to right in Hebrew too.
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.headlineMedium,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '',
                      ),
                    ),
                  ),
                  if (_number.text.isNotEmpty)
                    GestureDetector(
                      onLongPress: () => setState(() => _number.clear()),
                      child: IconButton(
                        tooltip: context.l10n.delete,
                        icon: const Icon(Icons.backspace_outlined),
                        onPressed: _backspace,
                      ),
                    ),
                ],
              ),
            ),
            DialKeypad(onKey: _type, onLongKey: _longPress),
            const SizedBox(height: 12),
            SizedBox(
              width: 72,
              height: 72,
              child: FloatingActionButton(
                heroTag: 'dial',
                shape: const CircleBorder(),
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                tooltip: context.l10n.call,
                onPressed: () => _call(_number.text),
                child: const Icon(Icons.call, size: 32),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// 1-9, *, 0, # with letters. Long-press 0 for +. Also used in calls.
class DialKeypad extends StatelessWidget {
  const DialKeypad({
    super.key,
    required this.onKey,
    this.foreground,
    this.onLongKey,
  });

  final ValueChanged<String> onKey;
  final Color? foreground;

  /// Long-press on 1 to 9 (voicemail and speed dial). Null in calls.
  final ValueChanged<String>? onLongKey;

  static const List<(String, String)> keys = <(String, String)>[
    ('1', ''), ('2', 'ABC'), ('3', 'DEF'), //
    ('4', 'GHI'), ('5', 'JKL'), ('6', 'MNO'),
    ('7', 'PQRS'), ('8', 'TUV'), ('9', 'WXYZ'),
    ('*', ''), ('0', '+'), ('#', ''),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      // A phone keypad is the same in every language: 1 2 3 left to right.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: <Widget>[
            for (final (String digit, String letters) in keys)
              Semantics(
                button: true,
                label: switch (digit) {
                  '0' => context.l10n.keyZeroHold,
                  '1' when onLongKey != null => context.l10n.keyOneHold,
                  _ => digit,
                },
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onKey(digit),
                  onLongPress: digit == '0'
                      ? () => onKey('+')
                      : (onLongKey != null && RegExp(r'^[1-9]$').hasMatch(digit)
                            ? () => onLongKey!(digit)
                            : null),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        digit,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                      if (digit == '1' && onLongKey != null)
                        Icon(
                          Icons.voicemail,
                          size: 14,
                          color:
                              foreground ?? theme.colorScheme.onSurfaceVariant,
                        )
                      else
                        Text(
                          letters,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color:
                                foreground ??
                                theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
