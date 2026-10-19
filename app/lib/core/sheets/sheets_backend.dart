import 'sheet_schema.dart';

/// A spreadsheet file created by this app (found through its Drive `appProperties` tag).
class SpreadsheetFile {
  const SpreadsheetFile({required this.id, required this.name, required this.createdTime, required this.modifiedTime});

  final String id;
  final String name;
  final DateTime createdTime;

  /// Drive `modifiedTime`: the cheap "did anything change?" probe of the sync cycle.
  final DateTime modifiedTime;
}

/// A tab as it exists in the spreadsheet.
class TabInfo {
  const TabInfo({required this.sheetId, required this.title});
  final int sheetId;
  final String title;
}

/// Where an append landed. [firstRow] is 1-based.
class AppendResult {
  const AppendResult({required this.firstRow, required this.rowCount});
  final int firstRow;
  final int rowCount;
}

/// The Drive + Sheets operations the app needs. Everything above this interface (bootstrap, sync) is pure
/// Dart and tested against an in-memory fake; [GoogleSheetsBackend] is the real implementation.
///
/// Cell values are plain JSON values (`String`, `num`, `bool`, `null`). Writes are *raw*: a string such as
/// `=SUM(A1)` or `2026-10-19` is stored literally, never interpreted, so user text cannot become a formula.
/// Reads are *unformatted*: booleans come back as `bool`, numbers as `num`, text as `String`. Trailing empty
/// cells and empty trailing rows are omitted by Sheets, so returned rows can be shorter than the header.
abstract interface class SheetsBackend {
  /// Spreadsheets created by this app, oldest first (ties broken by id).
  Future<List<SpreadsheetFile>> findSpreadsheets();

  /// Creates an empty spreadsheet tagged as this app's.
  Future<SpreadsheetFile> createSpreadsheet(String title);

  /// The file, or null when it no longer exists or is in the trash.
  Future<SpreadsheetFile?> getFile(String spreadsheetId);

  /// Moves a file to the Drive trash (recoverable).
  Future<void> trashFile(String spreadsheetId);

  Future<List<TabInfo>> listTabs(String spreadsheetId);

  /// Adds [add] (with a frozen bold header row and plain-text format on textual columns) and then removes the
  /// tabs [removeSheetIds], in one request. Adding comes first so the last tab is never removed.
  Future<void> changeTabs(String spreadsheetId, {List<TabSpec> add = const [], List<int> removeSheetIds = const []});

  /// One `values.batchGet`. Returns one row list per range, in order.
  Future<List<List<List<Object?>>>> readRanges(String spreadsheetId, List<String> ranges);

  /// One `values.batchUpdate`. Keys are A1 ranges. With [userEntered] the values are parsed as if typed
  /// (needed only for formulas).
  Future<void> writeRanges(String spreadsheetId, Map<String, List<List<Object?>>> data, {bool userEntered = false});

  /// One `values.append` of whole rows at the end of [tab]'s data.
  Future<AppendResult> appendRows(String spreadsheetId, String tab, List<List<Object?>> rows);
}
