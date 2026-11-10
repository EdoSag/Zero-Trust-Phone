import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_phone/data/phone_items.dart';
import 'package:zerotrust_phone/services/history_backup.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Call history backup')),
      body: ListView(
        children: <Widget>[
          if (_busy) const LinearProgressIndicator(),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_sync_outlined),
            title: const Text('Back up call history'),
            subtitle: const Text(
              'End-to-end encrypted in your account, so a new phone can get '
              'it back. Only you can read it.',
            ),
            value: p.backupHistory,
            onChanged: _busy
                ? null
                : (bool on) => _run(() async {
                    await data.saveProtection(p.copyWith(backupHistory: on));
                    if (on) {
                      final int n = await backup.backUp();
                      return 'Backed up $n ${n == 1 ? 'call' : 'calls'}';
                    }
                    await backup.deleteAll();
                    return 'Backup turned off and deleted';
                  }),
          ),
          ListTile(
            enabled: p.backupHistory && !_busy,
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Back up now'),
            onTap: () => _run(() async {
              final int n = await backup.backUp();
              return n == 0
                  ? 'Already up to date'
                  : 'Backed up $n ${n == 1 ? 'call' : 'calls'}';
            }),
          ),
          ListTile(
            enabled: !_busy,
            leading: const Icon(Icons.restore),
            title: const Text('Restore to this phone'),
            subtitle: const Text(
              'Adds backed-up calls missing from this phone\'s history',
            ),
            onTap: () => _run(() async {
              final int n = await backup.restore();
              return n == 0
                  ? 'Nothing to restore'
                  : 'Restored $n ${n == 1 ? 'call' : 'calls'}';
            }),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'The backup follows "Keep call history": older calls are '
              'removed from it too. Deleting a call in Recents also deletes '
              'its backup.',
            ),
          ),
        ],
      ),
    );
  }
}
