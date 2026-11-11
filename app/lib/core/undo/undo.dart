import '../sync/local_writer.dart';
import '../sync/record.dart';

/// A row of a tab, by id.
typedef RowRef = ({String tab, String id});

/// Columns that every write sets itself; they are never restored, so undoing still writes a new version.
const _bookkeeping = {'id', 'created_at', 'updated_at', 'version', 'device'};

/// How to reverse one change: the columns it changed on some rows, put back as they were, and the rows it created,
/// tombstoned.
class UndoEntry {
  const UndoEntry({required this.label, this.restore = const [], this.created = const []});

  /// What was done, as the user would say it ("Task completed").
  final String label;

  /// The changed columns of each row, as they were before.
  final List<({RowRef row, Fields before})> restore;

  /// Rows the change made; undoing tombstones them.
  final List<RowRef> created;

  bool get isEmpty => restore.isEmpty && created.isEmpty;
}

/// Runs [body], which writes through [writer], and works out how to reverse it. Returns null when it changed nothing.
///
/// [rows] are the rows [body] may change: each is read first and again afterwards, and only the columns that differ
/// are remembered, so undoing leaves alone whatever else changed on those rows in the meantime (another column edited
/// on another device, say). [body] returns the rows it created. All of it is one transaction, so a failing [body]
/// leaves nothing behind.
Future<UndoEntry?> recordUndo(
  LocalWriter writer,
  String label,
  List<RowRef> rows,
  Future<Iterable<RowRef>> Function() body,
) {
  return writer.store.transaction(() async {
    final before = <RowRef, Fields>{};
    for (final r in rows) {
      final row = await writer.store.getRow(r.tab, r.id);
      if (row != null) before[r] = Map.of(row.fields);
    }
    final created = (await body()).toList();
    final restore = <({RowRef row, Fields before})>[];
    for (final e in before.entries) {
      final after = (await writer.store.getRow(e.key.tab, e.key.id))?.fields;
      if (after == null) continue;
      final changed = <String, Object?>{
        for (final col in after.keys)
          if (!_bookkeeping.contains(col) && e.value[col] != after[col]) col: e.value[col],
      };
      if (changed.isNotEmpty) restore.add((row: e.key, before: changed));
    }
    final entry = UndoEntry(label: label, restore: restore, created: created);
    return entry.isEmpty ? null : entry;
  });
}

/// Reverses [entry], through [writer], so every row it touches gets a new `version` and syncs. One transaction.
Future<void> applyUndo(LocalWriter writer, UndoEntry entry) {
  return writer.store.transaction(() async {
    for (final r in entry.restore) {
      await writer.update(r.row.tab, r.row.id, r.before);
    }
    for (final c in entry.created) {
      await writer.delete(c.tab, c.id);
    }
  });
}
