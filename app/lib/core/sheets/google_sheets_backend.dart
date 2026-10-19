import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

import 'backoff.dart';
import 'sheet_schema.dart';
import 'sheets_backend.dart';

const _sheetMime = 'application/vnd.google-apps.spreadsheet';
const _fileFields = 'id,name,createdTime,modifiedTime';

/// [SheetsBackend] over the Drive v3 and Sheets v4 REST APIs.
///
/// [client] must be an authenticated client with the `drive.file` scope. Every call is retried with
/// exponential backoff on HTTP 429 and 5xx.
class GoogleSheetsBackend implements SheetsBackend {
  GoogleSheetsBackend(http.Client client, {this.sleep})
    : _drive = drive.DriveApi(client),
      _sheets = sheets.SheetsApi(client);

  final drive.DriveApi _drive;
  final sheets.SheetsApi _sheets;

  /// Replaces the real wait between retries (for tests).
  final Future<void> Function(Duration)? sleep;

  Future<T> _call<T>(Future<T> Function() action) =>
      retryWithBackoff(action, isRetryable: isTransientApiError, sleep: sleep);

  @override
  Future<List<SpreadsheetFile>> findSpreadsheets() async {
    final res = await _call(
      () => _drive.files.list(
        q:
            "mimeType='$_sheetMime' and trashed=false and "
            "appProperties has { key='$kAppPropertyKey' and value='$kAppPropertyValue' }",
        spaces: 'drive',
        pageSize: 100,
        $fields: 'files($_fileFields)',
      ),
    );
    final files = [for (final f in res.files ?? const <drive.File>[]) _toFile(f)]
      ..sort((a, b) {
        final c = a.createdTime.compareTo(b.createdTime);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return files;
  }

  @override
  Future<SpreadsheetFile> createSpreadsheet(String title) async {
    final created = await _call(
      () => _drive.files.create(
        drive.File(name: title, mimeType: _sheetMime, appProperties: {kAppPropertyKey: kAppPropertyValue}),
        $fields: _fileFields,
      ),
    );
    return _toFile(created);
  }

  @override
  Future<SpreadsheetFile?> getFile(String spreadsheetId) async {
    try {
      final f =
          await _call(() => _drive.files.get(spreadsheetId, $fields: '$_fileFields,trashed')) as drive.File;
      return f.trashed == true ? null : _toFile(f);
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<void> trashFile(String spreadsheetId) async {
    await _call(() => _drive.files.update(drive.File(trashed: true), spreadsheetId, $fields: 'id'));
  }

  @override
  Future<List<TabInfo>> listTabs(String spreadsheetId) async {
    final ss = await _call(
      () => _sheets.spreadsheets.get(spreadsheetId, $fields: 'sheets.properties(sheetId,title)'),
    );
    return [
      for (final s in ss.sheets ?? const <sheets.Sheet>[])
        TabInfo(sheetId: s.properties!.sheetId!, title: s.properties!.title!),
    ];
  }

  @override
  Future<void> changeTabs(
    String spreadsheetId, {
    List<TabSpec> add = const [],
    List<int> removeSheetIds = const [],
  }) async {
    final existing = await listTabs(spreadsheetId);
    var nextId = existing.fold<int>(0, (m, t) => t.sheetId > m ? t.sheetId : m) + 1;

    final requests = <sheets.Request>[];
    for (final spec in add) {
      final sheetId = nextId++;
      final columns = spec.columns;
      requests.add(
        sheets.Request(
          addSheet: sheets.AddSheetRequest(
            properties: sheets.SheetProperties(
              sheetId: sheetId,
              title: spec.name,
              gridProperties: sheets.GridProperties(
                rowCount: 1000,
                columnCount: columns.isEmpty ? 26 : columns.length,
                frozenRowCount: columns.isEmpty ? 0 : 1,
              ),
            ),
          ),
        ),
      );
      if (columns.isEmpty) continue;
      requests.add(_boldHeader(sheetId, columns.length));
      // Plain-text format on every contiguous run of textual columns (header row included), so values typed
      // by hand stay literal instead of turning into dates or numbers.
      int? runStart;
      for (var i = 0; i <= columns.length; i++) {
        final textual = i < columns.length && columns[i].type.isTextual;
        if (textual) {
          runStart ??= i;
        } else if (runStart != null) {
          requests.add(_plainText(sheetId, runStart, i));
          runStart = null;
        }
      }
    }
    for (final id in removeSheetIds) {
      requests.add(sheets.Request(deleteSheet: sheets.DeleteSheetRequest(sheetId: id)));
    }
    if (requests.isEmpty) return;
    await _call(
      () => _sheets.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: requests),
        spreadsheetId,
      ),
    );
  }

  sheets.Request _boldHeader(int sheetId, int width) => sheets.Request(
    repeatCell: sheets.RepeatCellRequest(
      range: sheets.GridRange(
        sheetId: sheetId,
        startRowIndex: 0,
        endRowIndex: 1,
        startColumnIndex: 0,
        endColumnIndex: width,
      ),
      cell: sheets.CellData(userEnteredFormat: sheets.CellFormat(textFormat: sheets.TextFormat(bold: true))),
      fields: 'userEnteredFormat.textFormat.bold',
    ),
  );

  sheets.Request _plainText(int sheetId, int fromColumn, int toColumnExclusive) => sheets.Request(
    repeatCell: sheets.RepeatCellRequest(
      range: sheets.GridRange(
        sheetId: sheetId,
        startRowIndex: 0,
        startColumnIndex: fromColumn,
        endColumnIndex: toColumnExclusive,
      ),
      cell: sheets.CellData(userEnteredFormat: sheets.CellFormat(numberFormat: sheets.NumberFormat(type: 'TEXT'))),
      fields: 'userEnteredFormat.numberFormat',
    ),
  );

  @override
  Future<List<List<List<Object?>>>> readRanges(String spreadsheetId, List<String> ranges) async {
    final res = await _call(
      () => _sheets.spreadsheets.values.batchGet(
        spreadsheetId,
        ranges: ranges,
        majorDimension: 'ROWS',
        valueRenderOption: 'UNFORMATTED_VALUE',
      ),
    );
    final ranged = res.valueRanges ?? const <sheets.ValueRange>[];
    return [
      for (var i = 0; i < ranges.length; i++)
        if (i < ranged.length) [for (final row in ranged[i].values ?? const <List<Object?>>[]) row] else const [],
    ];
  }

  @override
  Future<void> writeRanges(
    String spreadsheetId,
    Map<String, List<List<Object?>>> data, {
    bool userEntered = false,
  }) async {
    if (data.isEmpty) return;
    await _call(
      () => _sheets.spreadsheets.values.batchUpdate(
        sheets.BatchUpdateValuesRequest(
          valueInputOption: userEntered ? 'USER_ENTERED' : 'RAW',
          data: [for (final e in data.entries) sheets.ValueRange(range: e.key, values: e.value)],
        ),
        spreadsheetId,
      ),
    );
  }

  @override
  Future<AppendResult> appendRows(String spreadsheetId, String tab, List<List<Object?>> rows) async {
    final res = await _call(
      () => _sheets.spreadsheets.values.append(
        sheets.ValueRange(values: rows),
        spreadsheetId,
        '$tab!A1',
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      ),
    );
    final range = res.updates?.updatedRange;
    if (range == null) throw StateError('Sheets append returned no updatedRange');
    return AppendResult(firstRow: firstRowOfRange(range), rowCount: res.updates?.updatedRows ?? rows.length);
  }

  SpreadsheetFile _toFile(drive.File f) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return SpreadsheetFile(
      id: f.id!,
      name: f.name ?? '',
      createdTime: f.createdTime ?? epoch,
      modifiedTime: f.modifiedTime ?? epoch,
    );
  }
}

/// True for HTTP 429 and 5xx, the errors worth retrying.
bool isTransientApiError(Object error) =>
    error is drive.DetailedApiRequestError && (error.status == 429 || (error.status ?? 0) >= 500);

/// First row (1-based) of an A1 range as returned in `updates.updatedRange`:
/// `tasks!A5:AB6` → 5, `'My Tab'!A12` → 12.
int firstRowOfRange(String a1) {
  final m = RegExp(r'!\$?[A-Z]+\$?(\d+)').firstMatch(a1);
  if (m == null) throw FormatException('Cannot find a row in range', a1);
  return int.parse(m.group(1)!);
}
