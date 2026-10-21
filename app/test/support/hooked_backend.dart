import 'package:sheettick/core/sheets/sheet_schema.dart';
import 'package:sheettick/core/sheets/sheets_backend.dart';

import 'fake_sheets_backend.dart';

/// Wraps a [FakeSheetsBackend] and lets a test change the Sheet at a precise moment of a sync cycle, e.g.
/// right after the pull has read it and before the push writes.
class HookedBackend implements SheetsBackend {
  HookedBackend(this.inner);

  final FakeSheetsBackend inner;

  /// Runs once, right after the next [readRanges] has returned its data.
  void Function()? afterNextRead;

  @override
  Future<List<List<List<Object?>>>> readRanges(String spreadsheetId, List<String> ranges) async {
    final out = await inner.readRanges(spreadsheetId, ranges);
    final hook = afterNextRead;
    afterNextRead = null;
    hook?.call();
    return out;
  }

  @override
  Future<List<SpreadsheetFile>> findSpreadsheets() => inner.findSpreadsheets();
  @override
  Future<SpreadsheetFile> createSpreadsheet(String title) => inner.createSpreadsheet(title);
  @override
  Future<SpreadsheetFile?> getFile(String id) => inner.getFile(id);
  @override
  Future<void> trashFile(String id) => inner.trashFile(id);
  @override
  Future<List<TabInfo>> listTabs(String id) => inner.listTabs(id);
  @override
  Future<void> changeTabs(String id, {List<TabSpec> add = const [], List<int> removeSheetIds = const []}) =>
      inner.changeTabs(id, add: add, removeSheetIds: removeSheetIds);
  @override
  Future<void> writeRanges(String id, Map<String, List<List<Object?>>> data, {bool userEntered = false}) =>
      inner.writeRanges(id, data, userEntered: userEntered);
  @override
  Future<AppendResult> appendRows(String id, String tab, List<List<Object?>> rows) =>
      inner.appendRows(id, tab, rows);
}
