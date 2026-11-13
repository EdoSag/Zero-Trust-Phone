import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_phone/contacts/phone_contact.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';
import 'package:zerotrust_phone/pages/call_actions.dart';
import 'package:zerotrust_phone/util/dial_sequence.dart';
import 'package:zerotrust_phone/util/phone_numbers.dart';

/// Dial with pauses (P15): "call, wait, then send 1234#" as a simple form,
/// saved for a contact or number so it's one tap next time.
class DialShortcutPage extends ConsumerStatefulWidget {
  const DialShortcutPage({
    super.key,
    this.shortcut,
    this.number = '',
    this.contact,
    this.hideCallerId = false,
  });

  /// "My number hidden" was on in the dialpad (P22): calls from here keep it.
  final bool hideCallerId;

  /// The saved shortcut to edit; null for a new one.
  final DialShortcut? shortcut;

  /// For a new shortcut: the number, maybe with pauses already typed.
  final String number;
  final PhoneContact? contact;

  @override
  ConsumerState<DialShortcutPage> createState() => _DialShortcutPageState();
}

class _DialShortcutPageState extends ConsumerState<DialShortcutPage> {
  late final TextEditingController _label;
  late final TextEditingController _number;
  late List<DialStep> _steps;
  final List<TextEditingController> _tones = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    final DialShortcut? s = widget.shortcut;
    final (String number, String post) = s != null
        ? (s.number, s.postDial)
        : DialSequence.split(widget.number);
    _label = TextEditingController(text: s?.label ?? '');
    _number = TextEditingController(text: number);
    _steps = DialSequence.decode(post);
    // A new one starts as the usual "wait, then send a code".
    if (_steps.isEmpty) {
      _steps = <DialStep>[const DialStep.pause(), const DialStep.tones('')];
    }
    for (final DialStep step in _steps) {
      _tones.add(TextEditingController(text: step.tones));
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _number.dispose();
    for (final TextEditingController c in _tones) {
      c.dispose();
    }
    super.dispose();
  }

  List<DialStep> get _current => <DialStep>[
    for (int i = 0; i < _steps.length; i++)
      if (_steps[i].kind == DialStepKind.tones)
        DialStep.tones(_tones[i].text)
      else
        _steps[i],
  ];

  String get _postDial => DialSequence.encode(_current);

  String get _cleanNumber =>
      _number.text.trim().replaceAll(RegExp(r'[^0-9+*#]'), '');

  void _add(DialStep step) => setState(() {
    _steps.add(step);
    _tones.add(TextEditingController(text: step.tones));
  });

  void _remove(int i) => setState(() {
    _steps.removeAt(i);
    _tones.removeAt(i).dispose();
  });

  void _setPauses(int i, int count) =>
      setState(() => _steps[i] = DialStep.pause(count.clamp(1, 10)));

  Future<void> _save() async {
    if (_cleanNumber.isEmpty) return;
    final DialShortcut? old = widget.shortcut;
    final String label = _label.text.trim();
    await ref
        .read(phoneDataProvider)
        .saveDialShortcut(
          DialShortcut(
            id: old?.id ?? _newId(),
            label: label.isEmpty
                ? context.l10n.dialShortcutDefaultLabel
                : label,
            number: _cleanNumber,
            postDial: _postDial,
            contactId: old?.contactId ?? widget.contact?.id,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _call() async {
    if (_cleanNumber.isEmpty) return;
    await placeCall(
      ref,
      '$_cleanNumber$_postDial',
      hideCallerId: widget.hideCallerId,
    );
  }

  Future<void> _delete() async {
    final DialShortcut? old = widget.shortcut;
    if (old == null) return;
    await ref.read(phoneDataProvider).deleteDialShortcut(old.id);
    if (mounted) Navigator.of(context).pop();
  }

  static String _newId() {
    final Random r = Random.secure();
    return 'dial_${List<String>.generate(16, (_) => r.nextInt(16).toRadixString(16)).join()}';
  }

  @override
  Widget build(BuildContext context) {
    final AppL10n l = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.dialWithPauses),
        actions: <Widget>[
          if (widget.shortcut != null)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(l.dialWithPausesExplain),
          const SizedBox(height: 16),
          TextField(
            controller: _label,
            decoration: InputDecoration(
              labelText: l.dialShortcutName,
              hintText: l.dialShortcutNameHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _number,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l.numberToCall,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.call_outlined),
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < _steps.length; i++)
            _StepRow(
              key: ObjectKey(_tones[i]),
              index: i,
              step: _steps[i],
              tones: _tones[i],
              onChanged: () => setState(() {}),
              onPauses: (int n) => _setPauses(i, n),
              onRemove: () => _remove(i),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ActionChip(
                avatar: const Icon(Icons.hourglass_bottom, size: 18),
                label: Text(l.addPause),
                onPressed: () => _add(const DialStep.pause()),
              ),
              ActionChip(
                avatar: const Icon(Icons.touch_app_outlined, size: 18),
                label: Text(l.addWaitForTap),
                onPressed: () => _add(const DialStep.wait()),
              ),
              ActionChip(
                avatar: const Icon(Icons.dialpad, size: 18),
                label: Text(l.addTones),
                onPressed: () => _add(const DialStep.tones('')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.dialsAs, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    ltr('$_cleanNumber$_postDial'),
                    style: theme.textTheme.titleMedium,
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.call),
                  label: Text(l.callNow),
                  onPressed: _cleanNumber.isEmpty ? null : _call,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l.save),
                  onPressed: _cleanNumber.isEmpty ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.index,
    required this.step,
    required this.tones,
    required this.onChanged,
    required this.onPauses,
    required this.onRemove,
  });

  final int index;
  final DialStep step;
  final TextEditingController tones;
  final VoidCallback onChanged;
  final ValueChanged<int> onPauses;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppL10n l = context.l10n;
    final Widget body = switch (step.kind) {
      DialStepKind.pause => Row(
        children: <Widget>[
          Expanded(
            child: Text(l.pauseSeconds(step.count * DialSequence.pauseSeconds)),
          ),
          IconButton(
            tooltip: l.shorterPause,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: step.count > 1 ? () => onPauses(step.count - 1) : null,
          ),
          IconButton(
            tooltip: l.longerPause,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: step.count < 10 ? () => onPauses(step.count + 1) : null,
          ),
        ],
      ),
      DialStepKind.wait => Text(l.waitForTapStep),
      DialStepKind.tones => TextField(
        controller: tones,
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          isDense: true,
          labelText: l.tonesToSend,
          hintText: '1234#',
        ),
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          CircleAvatar(radius: 14, child: Text('${index + 1}')),
          const SizedBox(width: 12),
          Expanded(child: body),
          IconButton(
            tooltip: l.removeStep,
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// The saved "dial with pauses" shortcuts for a contact or number, each one
/// tap to call. Nothing when there are none.
class DialShortcutTiles extends ConsumerWidget {
  const DialShortcutTiles({
    super.key,
    required this.numbers,
    this.contact,
    this.onBeforeCall,
  });

  final List<String> numbers;
  final PhoneContact? contact;

  /// Called before calling or editing (e.g. to close a sheet).
  final VoidCallback? onBeforeCall;

  static List<DialShortcut> matching(
    List<DialShortcut> all,
    List<String> numbers,
    String? contactId,
  ) => all
      .where(
        (DialShortcut s) =>
            (contactId != null && s.contactId == contactId) ||
            numbers.any((String n) => PhoneNumbers.same(n, s.number)),
      )
      .toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<DialShortcut> mine = matching(
      ref.watch(dialShortcutsProvider).value ?? const <DialShortcut>[],
      numbers,
      contact?.id,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final DialShortcut s in mine)
          ListTile(
            leading: const Icon(Icons.dialpad),
            title: Text(s.label),
            subtitle: Text(ltr(s.dialString)),
            onTap: () {
              onBeforeCall?.call();
              placeCall(ref, s.dialString);
            },
            trailing: IconButton(
              tooltip: context.l10n.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                final NavigatorState nav = Navigator.of(context);
                onBeforeCall?.call();
                nav.push(
                  MaterialPageRoute<void>(
                    builder: (_) => DialShortcutPage(shortcut: s),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
