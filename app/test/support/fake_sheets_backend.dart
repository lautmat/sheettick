import 'package:sheettick/core/sheets/sheet_schema.dart';
import 'package:sheettick/core/sheets/sheets_backend.dart';

class _Tab {
  _Tab(this.sheetId, this.title);
  final int sheetId;
  String title;
  final List<List<Object?>> rows = [];
}

class _File {
  _File(this.id, this.name, this.createdTime, {required this.tagged});
  final String id;
  final String name;
  final DateTime createdTime;
  final bool tagged;
  DateTime modifiedTime = DateTime.utc(2026, 1, 1);
  bool trashed = false;
  final List<_Tab> tabs = [_Tab(0, 'Sheet1')];
}

/// In-memory stand-in for Drive + Sheets that mimics the behaviours the sync logic depends on:
/// ragged reads (trailing empty cells and rows are dropped), `null` cells are skipped on write, appends land
/// after the last used row, and every write bumps the file's `modifiedTime`.
///
/// Test hooks ([setCell], [insertRows], [deleteRow], [rawRows], [calls]) let tests play the role of a human
/// editing the Sheet or of a compaction job that shifts row numbers.
class FakeSheetsBackend implements SheetsBackend {
  final Map<String, _File> _files = {};
  int _clock = 0;
  int _nextId = 1;

  /// Number of calls per operation, to assert batching.
  final Map<String, int> calls = {};

  void _count(String op) => calls[op] = (calls[op] ?? 0) + 1;

  DateTime _tick() => DateTime.utc(2026, 1, 1).add(Duration(seconds: ++_clock));

  _File _file(String id) => _files[id] ?? (throw StateError('no such file $id'));

  _Tab _tab(String id, String title) => _file(id).tabs.firstWhere(
    (t) => t.title == title,
    orElse: () => throw StateError('no tab "$title" in $id'),
  );

  /// A spreadsheet that was not created by this app (no tag), e.g. one the user named `SheetTick` themselves.
  String addForeignSpreadsheet(String name) {
    final f = _File('file${_nextId++}', name, _tick(), tagged: false);
    _files[f.id] = f;
    return f.id;
  }

  @override
  Future<List<SpreadsheetFile>> findSpreadsheets() async {
    _count('findSpreadsheets');
    final found = _files.values.where((f) => f.tagged && !f.trashed).toList()
      ..sort((a, b) {
        final c = a.createdTime.compareTo(b.createdTime);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return [for (final f in found) _info(f)];
  }

  SpreadsheetFile _info(_File f) => SpreadsheetFile(
    id: f.id,
    name: f.name,
    createdTime: f.createdTime,
    modifiedTime: f.modifiedTime,
  );

  @override
  Future<SpreadsheetFile> createSpreadsheet(String title) async {
    _count('createSpreadsheet');
    final f = _File('file${_nextId++}', title, _tick(), tagged: true);
    _files[f.id] = f;
    return _info(f);
  }

  @override
  Future<SpreadsheetFile?> getFile(String spreadsheetId) async {
    _count('getFile');
    final f = _files[spreadsheetId];
    return f == null || f.trashed ? null : _info(f);
  }

  @override
  Future<void> trashFile(String spreadsheetId) async {
    _count('trashFile');
    _file(spreadsheetId).trashed = true;
  }

  @override
  Future<List<TabInfo>> listTabs(String spreadsheetId) async {
    _count('listTabs');
    return [for (final t in _file(spreadsheetId).tabs) TabInfo(sheetId: t.sheetId, title: t.title)];
  }

  @override
  Future<void> changeTabs(String spreadsheetId, {List<TabSpec> add = const [], List<int> removeSheetIds = const []}) async {
    _count('changeTabs');
    final f = _file(spreadsheetId);
    for (final spec in add) {
      if (f.tabs.any((t) => t.title == spec.name)) throw StateError('duplicate tab ${spec.name}');
      final nextSheetId = f.tabs.fold<int>(0, (m, t) => t.sheetId > m ? t.sheetId : m) + 1;
      f.tabs.add(_Tab(nextSheetId, spec.name));
    }
    f.tabs.removeWhere((t) => removeSheetIds.contains(t.sheetId));
    if (f.tabs.isEmpty) throw StateError('a spreadsheet must keep at least one tab');
    f.modifiedTime = _tick();
  }

  @override
  Future<List<List<List<Object?>>>> readRanges(String spreadsheetId, List<String> ranges) async {
    _count('readRanges');
    return [for (final r in ranges) _read(spreadsheetId, _Range.parse(r))];
  }

  List<List<Object?>> _read(String id, _Range r) {
    final tab = _tab(id, r.tab);
    final firstRow = (r.row0 ?? 1) - 1;
    final lastRow = r.row1 == null ? tab.rows.length - 1 : r.row1! - 1;
    final out = <List<Object?>>[];
    for (var i = firstRow; i <= lastRow && i < tab.rows.length; i++) {
      final row = tab.rows[i];
      final from = r.col0 ?? 0;
      final to = r.col1 == null ? row.length - 1 : r.col1!;
      final cells = <Object?>[for (var c = from; c <= to && c < row.length; c++) row[c]];
      out.add(_trimmed(cells));
    }
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out;
  }

  List<Object?> _trimmed(List<Object?> cells) {
    var end = cells.length;
    while (end > 0 && _isEmpty(cells[end - 1])) {
      end--;
    }
    return cells.sublist(0, end);
  }

  bool _isEmpty(Object? v) => v == null || v == '';

  @override
  Future<void> writeRanges(String spreadsheetId, Map<String, List<List<Object?>>> data, {bool userEntered = false}) async {
    _count('writeRanges');
    final f = _file(spreadsheetId);
    data.forEach((range, values) {
      final r = _Range.parse(range);
      final tab = _tab(spreadsheetId, r.tab);
      for (var i = 0; i < values.length; i++) {
        for (var j = 0; j < values[i].length; j++) {
          final v = values[i][j];
          if (v == null) continue; // Sheets skips nulls on update.
          _put(tab, (r.row0 ?? 1) - 1 + i, (r.col0 ?? 0) + j, v);
        }
      }
    });
    f.modifiedTime = _tick();
  }

  void _put(_Tab tab, int row, int col, Object? value) {
    while (tab.rows.length <= row) {
      tab.rows.add([]);
    }
    final cells = tab.rows[row];
    while (cells.length <= col) {
      cells.add(null);
    }
    cells[col] = value;
  }

  int _lastUsedRow(_Tab tab) {
    for (var i = tab.rows.length - 1; i >= 0; i--) {
      if (tab.rows[i].any((c) => !_isEmpty(c))) return i + 1;
    }
    return 0;
  }

  @override
  Future<AppendResult> appendRows(String spreadsheetId, String tab, List<List<Object?>> rows) async {
    _count('appendRows');
    final f = _file(spreadsheetId);
    final t = _tab(spreadsheetId, tab);
    final first = _lastUsedRow(t) + 1;
    for (var i = 0; i < rows.length; i++) {
      for (var j = 0; j < rows[i].length; j++) {
        _put(t, first - 1 + i, j, rows[i][j]);
      }
    }
    f.modifiedTime = _tick();
    return AppendResult(firstRow: first, rowCount: rows.length);
  }

  // ---- Test hooks -------------------------------------------------------------------------------------------

  /// A human typing into a cell. [row] is 1-based, [column] is a header name.
  void setCell(String spreadsheetId, String tab, int row, String column, Object? value) {
    final t = _tab(spreadsheetId, tab);
    if (t.rows.isEmpty) throw StateError('tab "$tab" has no rows, so there is no header to find column "$column"');
    final col = (t.rows.first.map((c) => '$c').toList()).indexOf(column);
    if (col < 0) throw StateError('no column $column in $tab');
    _put(t, row - 1, col, value);
    _file(spreadsheetId).modifiedTime = _tick();
  }

  /// Like [setCell] but addressing the column by 0-based position (to play with hand-reordered columns).
  void setCellAt(String spreadsheetId, String tab, int row, int column, Object? value) {
    _put(_tab(spreadsheetId, tab), row - 1, column, value);
    _file(spreadsheetId).modifiedTime = _tick();
  }

  /// Inserts [count] empty rows before 1-based [atRow], shifting everything below (a sort or a compaction).
  void insertRows(String spreadsheetId, String tab, int atRow, int count) {
    final t = _tab(spreadsheetId, tab);
    t.rows.insertAll(atRow - 1, List.generate(count, (_) => <Object?>[]));
    _file(spreadsheetId).modifiedTime = _tick();
  }

  /// Deletes the 1-based [row], shifting everything below up.
  void deleteRow(String spreadsheetId, String tab, int row) {
    _tab(spreadsheetId, tab).rows.removeAt(row - 1);
    _file(spreadsheetId).modifiedTime = _tick();
  }

  /// Snapshot of a tab's cells, row by row (including the header row).
  List<List<Object?>> rawRows(String spreadsheetId, String tab) => [
    for (final r in _tab(spreadsheetId, tab).rows) List<Object?>.of(r),
  ];

  /// Titles of the tabs in a spreadsheet.
  List<String> tabTitles(String spreadsheetId) => [for (final t in _file(spreadsheetId).tabs) t.title];
}

/// An A1 range: `tab!A:B`, `tab!1:1`, `tab!A2`, `tab!A2:AB9`. Indexes are 0-based for columns, 1-based for rows.
class _Range {
  _Range(this.tab, this.col0, this.row0, this.col1, this.row1);

  final String tab;
  final int? col0, col1;
  final int? row0, row1;

  static final _re = RegExp(r'^([^!]+)!([A-Z]*)(\d*)(?::([A-Z]*)(\d*))?$');

  static int? _col(String s) {
    if (s.isEmpty) return null;
    var n = 0;
    for (final u in s.codeUnits) {
      n = n * 26 + (u - 64);
    }
    return n - 1;
  }

  static int? _row(String s) => s.isEmpty ? null : int.parse(s);

  factory _Range.parse(String a1) {
    final m = _re.firstMatch(a1);
    if (m == null) throw ArgumentError('unsupported range $a1');
    final single = m.group(4) == null;
    final c0 = _col(m.group(2)!);
    final r0 = _row(m.group(3)!);
    return _Range(
      m.group(1)!,
      c0,
      r0,
      single ? c0 : _col(m.group(4)!),
      single ? r0 : _row(m.group(5)!),
    );
  }
}
