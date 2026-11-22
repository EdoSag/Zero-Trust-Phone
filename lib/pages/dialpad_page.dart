import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/app/call_comfort.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/pages/call_actions.dart';
import 'package:zerotrust_phone/pages/dial_shortcut_page.dart';
import 'package:zerotrust_phone/pages/speed_dial_page.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/dial_search.dart';
import 'package:zerotrust_phone/util/dial_sequence.dart';
import 'package:zerotrust_phone/util/pasted_numbers.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';
import 'package:zerotrust_phone/widgets/country_time_hint.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// The keypad. Typing digits also finds contacts by name or company, in
/// English or Hebrew, or by number (P14, see [DialSearch]).
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

  /// A key on the keypad: the chosen buzz and tone (P17), then the digit.
  void _press(String key) {
    final CallComfort comfort = ref.read(callComfortProvider);
    comfort.buzz();
    if (comfort.keyTones) {
      ref.read(telecomProvider).playKeyTone(key).ignore();
    }
    _type(key, buzz: false);
  }

  void _type(String key, {bool buzz = true}) {
    if (buzz) HapticFeedback.selectionClick();
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
      final bool placed = await placeCall(
        ref,
        dial.number,
        hideCallerId: _hideCallerId,
      );
      if (placed && mounted) Navigator.of(context).maybePop();
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

  /// [pickSim]: long-press on the call button picks the SIM (P18).
  Future<void> _call(String number, {bool pickSim = false}) async {
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
    final bool placed = await placeCall(
      ref,
      number.trim(),
      hideCallerId: _hideCallerId,
      pickSim: pickSim,
    );
    if (placed && mounted) Navigator.of(context).maybePop();
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
    final List<DialMatch> matches = DialSearch.search(contacts, digits);
    final ThemeData theme = Theme.of(context);

    final String? hint = countryHintText(context, ref, _number.text);
    final CallComfort comfort = ref.watch(callComfortProvider);

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
                  for (final DialMatch m in matches)
                    for (final String p in m.phones)
                      ListTile(
                        leading: ContactAvatar(label: m.contact.name),
                        title: Text(m.contact.name),
                        // Found by company: say which, so it's clear why.
                        subtitle: Text(
                          m.kind == DialMatchKind.company &&
                                  m.contact.company != m.contact.name
                              ? '${m.contact.company} · ${ltr(p)}'
                              : ltr(p),
                        ),
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
            DialKeypad(
              onKey: _press,
              onLongKey: _longPress,
              large: comfort.largeKeys,
              hand: comfort.hand,
              onSwitchHand: (KeypadHand to) => ref
                  .read(callComfortProvider.notifier)
                  .set(comfort.copyWith(hand: to)),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: switch (comfort.hand) {
                KeypadHand.both => Alignment.center,
                KeypadHand.left => const Alignment(-0.45, 0),
                KeypadHand.right => const Alignment(0.45, 0),
              },
              child: SizedBox(
                width: comfort.largeKeys ? 80 : 72,
                height: comfort.largeKeys ? 80 : 72,
                // Long-press: pick the SIM for this call (P18).
                // No tooltip: its own long-press would take the gesture.
                child: Semantics(
                  label: context.l10n.callHoldForSim,
                  button: true,
                  excludeSemantics: true,
                  onLongPress: () => _call(_number.text, pickSim: true),
                  child: GestureDetector(
                    key: const ValueKey<String>('dial-call'),
                    onLongPress: () => _call(_number.text, pickSim: true),
                    child: FloatingActionButton(
                      heroTag: 'dial',
                      shape: const CircleBorder(),
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      onPressed: () => _call(_number.text),
                      child: const Icon(Icons.call, size: 32),
                    ),
                  ),
                ),
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
    this.large = false,
    this.hand = KeypadHand.both,
    this.onSwitchHand,
  });

  final ValueChanged<String> onKey;
  final Color? foreground;

  /// Long-press on 1 to 9 (voicemail and speed dial), * and # (pause and
  /// wait). Null in calls.
  final ValueChanged<String>? onLongKey;

  /// P17: bigger keys and digits.
  final bool large;

  /// P17: one-handed mode, a narrower keypad on this side, with an arrow
  /// ([onSwitchHand]) that moves it to the other side.
  final KeypadHand hand;
  final ValueChanged<KeypadHand>? onSwitchHand;

  static const List<(String, String)> keys = <(String, String)>[
    ('1', ''), ('2', 'ABC'), ('3', 'DEF'), //
    ('4', 'GHI'), ('5', 'JKL'), ('6', 'MNO'),
    ('7', 'PQRS'), ('8', 'TUV'), ('9', 'WXYZ'),
    ('*', ''), ('0', '+'), ('#', ''),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hebrew = Localizations.localeOf(context).languageCode == 'he';
    final TextStyle? digitStyle =
        (large ? theme.textTheme.headlineLarge : theme.textTheme.headlineSmall)
            ?.copyWith(color: foreground);
    final TextStyle? letterStyle =
        (large ? theme.textTheme.labelMedium : theme.textTheme.labelSmall)
            ?.copyWith(color: foreground ?? theme.colorScheme.onSurfaceVariant);
    final Widget grid = GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: large
          ? (hand == KeypadHand.both ? 1.35 : 1.1)
          : (hand == KeypadHand.both ? 1.6 : 1.3),
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
                  : (onLongKey != null && RegExp(r'^[1-9*#]$').hasMatch(digit)
                        ? () => onLongKey!(digit)
                        : null),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(digit, style: digitStyle),
                  if (digit == '1' && onLongKey != null)
                    Icon(
                      Icons.voicemail,
                      size: 14,
                      color: foreground ?? theme.colorScheme.onSurfaceVariant,
                    )
                  else
                    Text(
                      // Hebrew letters too when the app is in Hebrew,
                      // where they sit on Israeli keypads.
                      hebrew && DialSearch.hebrewKeys[digit] != null
                          ? '$letters ${DialSearch.hebrewKeys[digit]}'
                          : letters,
                      style: letterStyle,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
    // A phone keypad is the same in every language: 1 2 3 left to right,
    // and "left hand" is the left side of the screen.
    if (hand == KeypadHand.both) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: large ? 16 : 32),
        child: Directionality(textDirection: TextDirection.ltr, child: grid),
      );
    }
    final bool left = hand == KeypadHand.left;
    final Widget mover = SizedBox(
      width: 48,
      child: IconButton(
        key: const ValueKey<String>('keypad-move'),
        tooltip: left
            ? context.l10n.keypadMoveRight
            : context.l10n.keypadMoveLeft,
        icon: Icon(left ? Icons.chevron_right : Icons.chevron_left),
        onPressed: onSwitchHand == null
            ? null
            : () => onSwitchHand!(left ? KeypadHand.right : KeypadHand.left),
      ),
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: <Widget>[
            if (!left) mover,
            Expanded(child: grid),
            if (left) mover,
          ],
        ),
      ),
    );
  }
}
