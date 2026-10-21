import 'package:drift/drift.dart';

import '../db/database.dart';
import '../sheets/sheet_schema.dart';
import 'record.dart';

/// The local SQLite side of sync, in the Sheet's vocabulary (column names, [Fields]).
///
/// The engine only talks to this interface and to `SheetsBackend`, so it can be exercised without a UI.
abstract interface class LocalStore {
  /// Runs [body] atomically: all of its writes happen or none do.
  Future<T> transaction<T>(Future<T> Function() body);

  Future<LocalRow?> getRow(String tab, String id);

  Future<Map<String, LocalRow>> rowsById(String tab);

  /// Number of rows waiting to be pushed, over [tabs].
  Future<int> dirtyCount(Iterable<String> tabs);

  /// Inserts or replaces the row with the same `id`.
  Future<void> putRow(String tab, LocalRow row);

  Future<void> setSheetRow(String tab, String id, int? sheetRow);

  /// Forgets every cached row number in [tab] (the Sheet was compacted).
  Future<void> clearSheetRows(String tab);

  /// Records that [fields] (at [pushedVersion]) is now in the Sheet at [sheetRow]. The dirty flag is cleared
  /// only if the row has not been edited again since: otherwise it stays dirty for the next push.
  Future<void> markPushed(
    String tab,
    String id, {
    required int pushedVersion,
    required int sheetRow,
    required String hash,
    required Fields fields,
  });

  /// [fields] with the table defaults filled in for empty values (the form local rows always have).
  Future<Fields> normalize(String tab, Fields fields);

  Future<String?> getState(String key);

  Future<void> setState(String key, String value);
}

class _ColumnInfo {
  _ColumnInfo(this.notNull, this.defaultValue);
  final bool notNull;
  final Object? defaultValue;
}

/// [LocalStore] over the drift [AppDatabase], using generic SQL driven by the tab specs of
/// `sheet_schema.dart`; the tables' column names are the Sheet's column names (checked by tests).
class DriftLocalStore implements LocalStore {
  DriftLocalStore(this._db);

  final AppDatabase _db;
  final Map<String, Map<String, _ColumnInfo>> _info = {};

  static const _bookkeeping = ['dirty', 'sheet_row', 'synced_hash', 'base_snapshot'];

  /// The drift table for [tab]. Every method resolves its table name here first, so a name that is not one of
  /// our tables never reaches the SQL built from it.
  TableInfo<Table, dynamic> _table(String tab) => _db.allTables.firstWhere(
    (t) => t.actualTableName == tab,
    orElse: () => throw ArgumentError.value(tab, 'tab', 'not a table of the local database'),
  );

  /// [tab] as a quoted SQL identifier, after checking it is one of our tables. Every statement that names a
  /// table goes through this, so nothing but a known table name is ever put into SQL.
  String _ident(String tab) {
    _table(tab);
    return '"$tab"';
  }
  Future<Map<String, _ColumnInfo>> _columns(String tab) async {
    final cached = _info[tab];
    if (cached != null) return cached;
    final rows = await _db.customSelect('PRAGMA table_info(${_ident(tab)})').get();
    return _info[tab] = {
      for (final r in rows)
        r.read<String>('name'): _ColumnInfo(r.read<int>('notnull') == 1, _parseDefault(r.data['dflt_value'])),
    };
  }

  /// `table_info` reports defaults as SQL literals: `''`, `'TEXT'`, `0`, `0.0`.
  static Object? _parseDefault(Object? literal) {
    if (literal == null) return null;
    final s = '$literal'.trim();
    if (s.length >= 2 && s.startsWith("'") && s.endsWith("'")) {
      return s.substring(1, s.length - 1).replaceAll("''", "'");
    }
    return num.tryParse(s);
  }

  @override
  Future<T> transaction<T>(Future<T> Function() body) => _db.transaction(body);

  @override
  Future<Fields> normalize(String tab, Fields fields) async {
    final info = await _columns(tab);
    final out = <String, Object?>{};
    for (final c in tabSpec(tab).columns) {
      final v = fields[c.name];
      out[c.name] = _fromDb(c.type, _toDb(c, v, _infoFor(tab, info, c.name)));
    }
    return out;
  }

  _ColumnInfo _infoFor(String tab, Map<String, _ColumnInfo> info, String column) =>
      info[column] ?? (throw StateError('Column "$column" is missing from table "$tab": was the database migrated?'));

  Object? _toDb(ColumnSpec c, Object? v, _ColumnInfo info) {
    if (v == null) {
      if (!info.notNull) return null;
      final d = info.defaultValue;
      if (d == null) throw StateError('Column "${c.name}" is required but has no value and no default');
      return d;
    }
    // An empty string only exists in textual columns: NULL where the column allows it, '' where it does not.
    if (v == '') return info.notNull ? '' : null;
    return switch (c.type) {
      ColumnType.boolean => (v as bool) ? 1 : 0,
      ColumnType.integer => (v as num).toInt(),
      ColumnType.number => (v as num).toDouble(),
      _ => '$v',
    };
  }

  Object? _fromDb(ColumnType type, Object? v) {
    if (v == null) return null;
    return switch (type) {
      ColumnType.boolean => v is bool ? v : (v as num) != 0,
      ColumnType.integer => (v as num).toInt(),
      ColumnType.number => (v as num).toDouble(),
      _ => v as String,
    };
  }

  LocalRow _decode(String tab, Map<String, Object?> data) {
    final fields = <String, Object?>{
      for (final c in tabSpec(tab).columns) c.name: _fromDb(c.type, data[c.name]),
    };
    final base = data['base_snapshot'] as String?;
    return LocalRow(
      fields: fields,
      dirty: (data['dirty'] as num?) == 1,
      sheetRow: (data['sheet_row'] as num?)?.toInt(),
      syncedHash: data['synced_hash'] as String?,
      baseSnapshot: base == null ? null : decodeSnapshot(base),
    );
  }

  @override
  Future<LocalRow?> getRow(String tab, String id) async {
    final rows = await _db
        .customSelect('SELECT * FROM ${_ident(tab)} WHERE id = ?1', variables: [Variable.withString(id)], readsFrom: {_table(tab)})
        .get();
    return rows.isEmpty ? null : _decode(tab, rows.first.data);
  }

  @override
  Future<Map<String, LocalRow>> rowsById(String tab) async {
    final rows = await _db.customSelect('SELECT * FROM ${_ident(tab)}', readsFrom: {_table(tab)}).get();
    final out = <String, LocalRow>{};
    for (final r in rows) {
      final row = _decode(tab, r.data);
      out[row.id] = row;
    }
    return out;
  }

  @override
  Future<int> dirtyCount(Iterable<String> tabs) async {
    var n = 0;
    for (final tab in tabs) {
      final r = await _db.customSelect('SELECT COUNT(*) AS n FROM ${_ident(tab)} WHERE dirty = 1').getSingle();
      n += r.read<int>('n');
    }
    return n;
  }

  static Variable _variable(Object? v) => switch (v) {
    null => const Variable<Object>(null),
    int() => Variable.withInt(v),
    double() => Variable.withReal(v),
    String() => Variable.withString(v),
    _ => throw ArgumentError('Unsupported value $v'),
  };

  @override
  Future<void> putRow(String tab, LocalRow row) async {
    final info = await _columns(tab);
    final spec = tabSpec(tab);
    final names = [...spec.columnNames, ..._bookkeeping];
    final values = <Object?>[
      for (final c in spec.columns) _toDb(c, row.fields[c.name], _infoFor(tab, info, c.name)),
      row.dirty ? 1 : 0,
      row.sheetRow,
      row.syncedHash,
      row.baseSnapshot == null ? null : encodeSnapshot(row.baseSnapshot!),
    ];
    final placeholders = List.generate(names.length, (i) => '?${i + 1}').join(', ');
    final updates = names.where((n) => n != 'id').map((n) => '$n = excluded.$n').join(', ');
    await _db.customInsert(
      'INSERT INTO ${_ident(tab)} (${names.join(', ')}) VALUES ($placeholders) ON CONFLICT(id) DO UPDATE SET $updates',
      variables: [for (final v in values) _variable(v)],
      updates: {_table(tab)},
    );
  }

  @override
  Future<void> setSheetRow(String tab, String id, int? sheetRow) async {
    await _db.customUpdate(
      'UPDATE ${_ident(tab)} SET sheet_row = ?1 WHERE id = ?2',
      variables: [_variable(sheetRow), Variable.withString(id)],
      updates: {_table(tab)},
      updateKind: UpdateKind.update,
    );
  }

  @override
  Future<void> clearSheetRows(String tab) async {
    await _db.customUpdate(
      'UPDATE ${_ident(tab)} SET sheet_row = NULL',
      updates: {_table(tab)},
      updateKind: UpdateKind.update,
    );
  }

  @override
  Future<void> markPushed(
    String tab,
    String id, {
    required int pushedVersion,
    required int sheetRow,
    required String hash,
    required Fields fields,
  }) => _db.transaction(() async {
    await _db.customUpdate(
      'UPDATE ${_ident(tab)} SET dirty = CASE WHEN version = ?1 THEN 0 ELSE dirty END, '
      'sheet_row = ?2, synced_hash = ?3, base_snapshot = ?4 WHERE id = ?5',
      variables: [
        Variable.withInt(pushedVersion),
        Variable.withInt(sheetRow),
        Variable.withString(hash),
        Variable.withString(encodeSnapshot(fields)),
        Variable.withString(id),
      ],
      updates: {_table(tab)},
      updateKind: UpdateKind.update,
    );
  });

  @override
  Future<String?> getState(String key) => _db.getDeviceState(key);

  @override
  Future<void> setState(String key, String value) => _db.setDeviceState(key, value);
}
