import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/services/history_backup.dart';
import 'package:zerotrust_phone/l10n/l10n.dart';

/// Encrypted call-history backup and restore (P9).
class HistoryBackupPage extends ConsumerStatefulWidget {
  const HistoryBackupPage({super.key});

  @override
  ConsumerState<HistoryBackupPage> createState() => _HistoryBackupPageState();
}

class _HistoryBackupPageState extends ConsumerState<HistoryBackupPage> {
  bool _busy = false;

  Future<void> _run(Future<String> Function() task) async {
    setState(() => _busy = true);
    String message;
    try {
      message = await task();
    } on Object catch (e) {
      message = ztErrorMessage(e);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final CallProtection p = ref.watch(callProtectionProvider);
    final PhoneData data = ref.read(phoneDataProvider);
    final HistoryBackup backup = ref.read(historyBackupProvider);

    final AppL10n l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.callHistoryBackup)),
      body: ListView(
        children: <Widget>[
          if (_busy) const LinearProgressIndicator(),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_sync_outlined),
            title: Text(l.backUpCallHistory),
            subtitle: Text(l.backUpCallHistoryBody),
            value: p.backupHistory,
            onChanged: _busy
                ? null
                : (bool on) => _run(() async {
                    await data.saveProtection(p.copyWith(backupHistory: on));
                    if (on) {
                      final int n = await backup.backUp();
                      return l.backedUpCalls(n);
                    }
                    await backup.deleteAll();
                    return l.backupDeleted;
                  }),
          ),
          ListTile(
            enabled: p.backupHistory && !_busy,
            leading: const Icon(Icons.backup_outlined),
            title: Text(l.backUpNow),
            onTap: () => _run(() async {
              final int n = await backup.backUp();
              return n == 0 ? l.alreadyUpToDate : l.backedUpCalls(n);
            }),
          ),
          ListTile(
            enabled: !_busy,
            leading: const Icon(Icons.restore),
            title: Text(l.restoreToPhone),
            subtitle: Text(l.restoreToPhoneBody),
            onTap: () => _run(() async {
              final int n = await backup.restore();
              return n == 0 ? l.nothingToRestore : l.restoredCalls(n);
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.backupExplain),
          ),
        ],
      ),
    );
  }
}
