import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/pages/call_actions.dart';
import 'package:zerotrust_phone/pages/dial_shortcut_page.dart';
import 'package:zerotrust_phone/pages/speed_dial_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/dial_sequence.dart';
import 'package:zerotrust_phone/util/pasted_numbers.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';
import 'package:zerotrust_phone/widgets/country_time_hint.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// The keypad. Typing digits also finds contacts by name (T9) or number.
class DialpadPage extends ConsumerStatefulWidget {
  const DialpadPage({super.key, this.initialNumber = '', this.initialText});

  final String initialNumber;

  /// Text shared or selected in another app ("ZT Phone" in Android's text
  /// menu or share sheet): the number in it is picked out, as on paste.
  final String? initialText;

  @override
  ConsumerState<DialpadPage> createState() => _DialpadPageState();
}

class _DialpadPageState extends ConsumerState<DialpadPage> {
  late final TextEditingController _number = TextEditingController(
    text: widget.initialNumber,
  );

  /// P22: hide my number on this call.
  bool _hideCallerId = false;

  @override
  void initState() {
    super.initState();
    final String? text = widget.initialText;
    if (text != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _useText(text));
    }
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  /// Paste and clean (P13): the clipboard is read only on this tap.
  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    await _useText(data?.text ?? '');
  }

  /// Puts the number found in [text] on the dialpad, cleaned, ready to call
  /// with one tap. Several numbers: the person picks one.
  Future<void> _useText(String text) async {
    final List<String> numbers = PastedNumbers.find(text);
    if (numbers.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.noNumberInText)));
      return;
    }
    final String? number = numbers.length == 1
        ? numbers.single
        : await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (BuildContext sheet) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(
                      sheet.l10n.whichNumber,
                      style: Theme.of(sheet).textTheme.titleMedium,
                    ),
                  ),
                  for (final String n in numbers)
                    ListTile(
                      leading: const Icon(Icons.call_outlined),
                      title: Text(ltr(n)),
                      onTap: () => Navigator.of(sheet).pop(n),
                    ),
                ],
              ),
            ),
          );
    if (number == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _number.value = TextEditingValue(
        text: number,
        selection: TextSelection.collapsed(offset: number.length),
      );
    });
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

  /// Long-press 1 calls voicemail (P5); 2 to 9 are speed dial (P8); * types
  /// a pause and # a wait (P15).
  Future<void> _longPress(String digit) async {
    HapticFeedback.heavyImpact();
    if (digit == '*' || digit == '#') {
      _type(digit == '*' ? ',' : ';');
      return;
    }
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
      await placeCall(ref, dial.number, hideCallerId: _hideCallerId);
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
    await placeCall(ref, number.trim(), hideCallerId: _hideCallerId);
    if (mounted) Navigator.of(context).maybePop();
  }

  void _openPauses() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DialShortcutPage(
        number: _number.text,
        hideCallerId: _hideCallerId,
        contact: ref
            .read(contactDirectoryProvider)
            .lookup(DialSequence.split(_number.text).$1),
      ),
    ),
  );

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

    final String? hint = countryHintText(context, ref, _number.text);

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.dialWithPauses,
            icon: const Icon(Icons.more_time),
            onPressed: _openPauses,
          ),
          IconButton(
            tooltip: _hideCallerId
                ? context.l10n.showMyNumber
                : context.l10n.hideMyNumber,
            isSelected: _hideCallerId,
            icon: const Icon(Icons.visibility_off_outlined),
            selectedIcon: const Icon(Icons.visibility_off),
            onPressed: () {
              setState(() => _hideCallerId = !_hideCallerId);
              // What hiding can't do, said each time it's switched on.
              final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                context,
              )..hideCurrentSnackBar();
              if (_hideCallerId) {
                messenger.showSnackBar(
                  SnackBar(content: Text(context.l10n.numberHiddenNotice)),
                );
              }
            },
          ),
        ],
      ),
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
                      // The field is typed on by the keypad, so Android's
                      // own Paste is off; this Paste cleans the number.
                      contextMenuBuilder:
                          (BuildContext menu, EditableTextState state) =>
                              AdaptiveTextSelectionToolbar.buttonItems(
                                anchors: state.contextMenuAnchors,
                                buttonItems: <ContextMenuButtonItem>[
                                  ...state.contextMenuButtonItems.where(
                                    (ContextMenuButtonItem b) =>
                                        b.type != ContextMenuButtonType.paste,
                                  ),
                                  ContextMenuButtonItem(
                                    type: ContextMenuButtonType.paste,
                                    onPressed: () {
                                      state.hideToolbar();
                                      _paste();
                                    },
                                  ),
                                ],
                              ),
                    ),
                  ),
                  if (_number.text.isEmpty)
                    IconButton(
                      tooltip: context.l10n.pasteNumber,
                      icon: const Icon(Icons.content_paste),
                      onPressed: _paste,
                    )
                  else
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
            // Country and time there (P16), and whether my number is hidden.
            SizedBox(
              height: 24,
              child: Semantics(
                liveRegion: true,
                child: Text(
                  <String>[
                    ?hint,
                    if (_hideCallerId) context.l10n.numberHidden,
                  ].join(' · '),
                  key: const ValueKey<String>('dial-hint'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
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

  /// Long-press on 1 to 9 (voicemail and speed dial), * and # (pause and
  /// wait). Null in calls.
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
                  '*' when onLongKey != null => context.l10n.keyStarHold,
                  '#' when onLongKey != null => context.l10n.keyHashHold,
                  _ => digit,
                },
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onKey(digit),
                  onLongPress: digit == '0'
                      ? () => onKey('+')
                      : (onLongKey != null &&
                                RegExp(r'^[1-9*#]$').hasMatch(digit)
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
