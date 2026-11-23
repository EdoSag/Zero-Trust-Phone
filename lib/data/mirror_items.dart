import 'dart:async';

import 'package:zero_trust_core/zero_trust_core.dart';

/// A parsed copy of the items in one of Phone's read-only mirrors (the
/// address book, the calendar), kept in memory and brought up to date item
/// by item.
///
/// The mirrors used to read and parse every item again on every change.
/// While a large address book arrived, that was the whole list, again and
/// again, on the screen thread. Here a change re-reads only the items that
/// changed; everything is read once at the start and once after each sync.
class MirrorItems<T> {
  MirrorItems({
    required this.liveItems,
    required this.get,
    required this.changes,
    required this.refreshed,
    required this.parse,
  });

  /// For a mirror kept in [store].
  MirrorItems.of(
    ZtLocalStore store, {
    required Stream<void> refreshed,
    required T? Function(String id, Map<String, Object?>? json) parse,
  }) : this(
         liveItems: store.liveItems,
         get: store.get,
         changes: store.changes,
         refreshed: refreshed,
         parse: parse,
       );

  /// Every item that isn't deleted.
  final Future<List<LocalItem>> Function() liveItems;

  /// One item by id, or null.
  final Future<LocalItem?> Function(String itemId) get;

  /// Ids of the items that changed, after each write.
  final Stream<Set<String>> changes;

  /// Ticks when a sync has finished: everything is read again, in case a
  /// change was missed.
  final Stream<void> refreshed;

  /// An item's JSON as [T], or null for kinds the mirror doesn't show.
  final T? Function(String id, Map<String, Object?>? json) parse;

  /// The items now, then again after every change. One round runs at a
  /// time; changes that arrive during a round are taken together in the
  /// next one.
  Stream<List<T>> watch() {
    final Map<String, T> items = <String, T>{};
    final Set<String> changed = <String>{};
    bool readAll = true;
    bool working = false;
    bool stopped = false;
    late final StreamController<List<T>> out;
    StreamSubscription<Set<String>>? onChange;
    StreamSubscription<void>? onRefresh;

    Future<void> work() async {
      if (working) return;
      working = true;
      try {
        while ((readAll || changed.isNotEmpty) && !stopped) {
          if (readAll) {
            readAll = false;
            changed.clear();
            final List<LocalItem> all = await liveItems();
            items.clear();
            for (final LocalItem item in all) {
              final T? parsed = parse(item.itemId, item.json);
              if (parsed != null) items[item.itemId] = parsed;
            }
          } else {
            final List<String> ids = changed.toList();
            changed.clear();
            for (final String id in ids) {
              final LocalItem? item = await get(id);
              final T? parsed = item == null || item.deleted
                  ? null
                  : parse(id, item.json);
              if (parsed == null) {
                items.remove(id);
              } else {
                items[id] = parsed;
              }
            }
          }
          if (!stopped) out.add(items.values.toList());
        }
      } on Object catch (e, s) {
        if (!stopped) out.addError(e, s);
      } finally {
        working = false;
      }
    }

    out = StreamController<List<T>>(
      onListen: () {
        // Listening before the first read, so nothing written meanwhile
        // is missed.
        onChange = changes.listen((Set<String> ids) {
          changed.addAll(ids);
          work();
        });
        onRefresh = refreshed.listen((_) {
          readAll = true;
          work();
        });
        work();
      },
      onCancel: () async {
        stopped = true;
        await onChange?.cancel();
        await onRefresh?.cancel();
      },
    );
    return out.stream;
  }
}
