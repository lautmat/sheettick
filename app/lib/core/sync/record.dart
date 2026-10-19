import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../sheets/sheet_schema.dart';

/// A row as the sync engine sees it: Sheet column name → Dart value.
///
/// Values are `String?` (uuid, text, markdown, enum, json, date/time columns), `int?`, `double?` or `bool`,
/// according to the column's [ColumnType]. Local bookkeeping is not part of it.
typedef Fields = Map<String, Object?>;

/// A row in the local database: its [fields] plus the bookkeeping of `docs/sync-protocol.md`.
class LocalRow {
  const LocalRow({
    required this.fields,
    this.dirty = false,
    this.sheetRow,
    this.syncedHash,
    this.baseSnapshot,
  });

  final Fields fields;

  /// Changed locally since the last push.
  final bool dirty;

  /// Cached 1-based row number in the tab.
  final int? sheetRow;

  /// Hash of the row's cells as last seen in the Sheet.
  final String? syncedHash;

  /// Field values at the last successful sync, for the three-way merge.
  final Fields? baseSnapshot;

  String get id => fields['id']! as String;
  int get version => (fields['version'] as int?) ?? 0;

  LocalRow copyWith({
    Fields? fields,
    bool? dirty,
    int? Function()? sheetRow,
    String? Function()? syncedHash,
    Fields? Function()? baseSnapshot,
  }) => LocalRow(
    fields: fields ?? this.fields,
    dirty: dirty ?? this.dirty,
    sheetRow: sheetRow != null ? sheetRow() : this.sheetRow,
    syncedHash: syncedHash != null ? syncedHash() : this.syncedHash,
    baseSnapshot: baseSnapshot != null ? baseSnapshot() : this.baseSnapshot,
  );
}

// ---- Cells <-> values -------------------------------------------------------------------------------------

/// A Sheet cell (as returned by an unformatted read) → the Dart value for a column of [type].
/// Empty cells are `null`. Anything that cannot be read as the column's type is `null` too, never an exception:
/// a human may type anything into a cell.
Object? decodeCell(ColumnType type, Object? cell) {
  if (cell == null || cell == '') return null;
  switch (type) {
    case ColumnType.boolean:
      if (cell is bool) return cell;
      if (cell is num) return cell != 0;
      final s = '$cell'.trim().toUpperCase();
      if (s == 'TRUE') return true;
      if (s == 'FALSE') return false;
      return null;
    case ColumnType.integer:
      if (cell is num) return cell.toInt();
      return int.tryParse('$cell'.trim()) ?? double.tryParse('$cell'.trim())?.toInt();
    case ColumnType.number:
      if (cell is num) return cell.toDouble();
      return double.tryParse('$cell'.trim());
    case ColumnType.uuid ||
        ColumnType.text ||
        ColumnType.markdown ||
        ColumnType.enumeration ||
        ColumnType.json ||
        ColumnType.datetime ||
        ColumnType.date ||
        ColumnType.timestamp:
      if (cell is num && cell == cell.truncate()) return '${cell.truncate()}';
      return '$cell';
  }
}

/// A Dart value → the cell to write. `null` becomes an empty string, which clears the cell (a `null` would
/// leave whatever is there).
Object encodeCell(Object? value) => switch (value) {
  null => '',
  bool() || int() || String() => value,
  double() => value == value.truncate() && value.abs() < 1e15 ? value.truncate() : value,
  _ => '$value',
};

/// True when [a] and [b] mean the same value: `null` and `''` are equal, numbers compare by value.
bool sameValue(Object? a, Object? b) {
  if ((a == null || a == '') && (b == null || b == '')) return true;
  if (a is num && b is num) return a.toDouble() == b.toDouble();
  return a == b;
}

String _canonical(Object? v) => switch (v) {
  null => '',
  bool() => v ? 'T' : 'F',
  double() => v == v.truncate() ? '${v.truncate()}' : '$v',
  _ => '$v',
};

/// Hash of a row's values over the [tab]'s schema columns. Two rows with the same visible content hash the
/// same whether they were read from the Sheet or are about to be written to it.
String rowHash(TabSpec tab, Fields fields) {
  final canonical = tab.columnNames.map((c) => _canonical(fields[c])).join('\u0001');
  return sha1.convert(utf8.encode(canonical)).toString();
}

String encodeSnapshot(Fields fields) => jsonEncode(fields);

Fields decodeSnapshot(String json) => Map<String, Object?>.from(jsonDecode(json) as Map);

// ---- Three-way merge --------------------------------------------------------------------------------------

/// Columns that are bookkeeping of the write itself and never merged field by field.
const kUnmergedColumns = {'id', 'created_at', 'updated_at', 'version', 'device'};

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// Whether the local version of a row wins a field that both sides changed: the newer `updated_at`, and on a
/// tie the larger `device` id, so every device reaches the same answer. If everything ties, the Sheet wins.
bool localWinsConflict(Fields local, Fields remote) {
  final l = _time(local['updated_at']);
  final r = _time(remote['updated_at']);
  if (l != null && r != null && l != r) return l.isAfter(r);
  final ld = '${local['device'] ?? ''}';
  final rd = '${remote['device'] ?? ''}';
  return ld != rd && ld.compareTo(rd) > 0;
}

/// Field-by-field three-way merge of [local] and [remote] against [base] (the last synced state; an empty map
/// when unknown, which makes every differing field a conflict). Only the columns in [columns] are merged.
///
/// A field changed on one side only takes that side's value. A field changed on both sides to different
/// values takes the value of the side [localWinsConflict] picks.
Fields mergeFields({
  required Fields base,
  required Fields local,
  required Fields remote,
  required Iterable<String> columns,
}) {
  final localWins = localWinsConflict(local, remote);
  final merged = <String, Object?>{};
  for (final c in columns) {
    final localChanged = !sameValue(local[c], base[c]);
    final remoteChanged = !sameValue(remote[c], base[c]);
    if (localChanged && remoteChanged && !sameValue(local[c], remote[c])) {
      merged[c] = localWins ? local[c] : remote[c];
    } else if (localChanged) {
      merged[c] = local[c];
    } else {
      merged[c] = remote[c];
    }
  }
  return merged;
}
