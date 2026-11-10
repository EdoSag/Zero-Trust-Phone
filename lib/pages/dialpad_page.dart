import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/contacts/vault_contacts.dart';
import 'package:zerotrust_phone/telecom/telecom.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';
import 'package:zerotrust_phone/widgets/contact_avatar.dart';

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
    await ref.read(telecomProvider).placeCall(number.trim());
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
                        subtitle: Text(p),
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
                        tooltip: 'Delete',
                        icon: const Icon(Icons.backspace_outlined),
                        onPressed: _backspace,
                      ),
                    ),
                ],
              ),
            ),
            DialKeypad(onKey: _type),
            const SizedBox(height: 12),
            SizedBox(
              width: 72,
              height: 72,
              child: FloatingActionButton(
                heroTag: 'dial',
                shape: const CircleBorder(),
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                tooltip: 'Call',
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
  const DialKeypad({super.key, required this.onKey, this.foreground});

  final ValueChanged<String> onKey;
  final Color? foreground;

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
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.6,
        children: <Widget>[
          for (final (String digit, String letters) in keys)
            Semantics(
              button: true,
              label: digit == '0' ? '0, hold for plus' : digit,
              excludeSemantics: true,
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onKey(digit),
                onLongPress: digit == '0' ? () => onKey('+') : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      digit,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: foreground,
                      ),
                    ),
                    Text(
                      letters,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground ?? theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
