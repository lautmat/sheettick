import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sheettick/core/sheets/google_sheets_backend.dart';
import 'package:sheettick/core/sheets/sheet_schema.dart';

/// What the backend sent, and a canned JSON reply chosen by [reply].
class _Wire {
  final requests = <http.Request>[];
  Map<String, Object?> Function(http.Request)? reply;
  int? failFirstWith;

  late final client = MockClient((req) async {
    requests.add(req);
    if (failFirstWith != null) {
      final status = failFirstWith!;
      failFirstWith = null;
      return http.Response(jsonEncode({'error': {'code': status, 'message': 'try later'}}), status,
          headers: {'content-type': 'application/json'});
    }
    return http.Response(jsonEncode(reply?.call(req) ?? {}), 200, headers: {'content-type': 'application/json'});
  });

  http.Request get last => requests.last;
  Map<String, dynamic> get lastBody => jsonDecode(last.body) as Map<String, dynamic>;
}

void main() {
  late _Wire wire;
  late GoogleSheetsBackend backend;

  setUp(() {
    wire = _Wire();
    backend = GoogleSheetsBackend(wire.client, sleep: (_) async {});
  });

  test('createSpreadsheet creates a Sheet file tagged with the app property', () async {
    wire.reply = (_) => {
      'id': 'abc',
      'name': 'SheetTick',
      'createdTime': '2026-10-19T13:05:00.000Z',
      'modifiedTime': '2026-10-19T13:05:00.000Z',
    };
    final f = await backend.createSpreadsheet('SheetTick');
    expect(f.id, 'abc');
    expect(f.createdTime, DateTime.utc(2026, 10, 19, 13, 5));
    expect(wire.last.method, 'POST');
    expect(wire.lastBody['mimeType'], 'application/vnd.google-apps.spreadsheet');
    expect(wire.lastBody['name'], 'SheetTick');
    expect(wire.lastBody['appProperties'], {kAppPropertyKey: kAppPropertyValue});
  });

  test('findSpreadsheets only asks for live, tagged spreadsheets and returns the oldest first', () async {
    wire.reply = (_) => {
      'files': [
        {'id': 'newer', 'name': 'SheetTick', 'createdTime': '2026-02-01T00:00:00Z', 'modifiedTime': '2026-02-01T00:00:00Z'},
        {'id': 'older', 'name': 'SheetTick', 'createdTime': '2026-01-01T00:00:00Z', 'modifiedTime': '2026-01-01T00:00:00Z'},
      ],
    };
    final files = await backend.findSpreadsheets();
    expect(files.map((f) => f.id), ['older', 'newer']);
    final q = wire.last.url.queryParameters['q']!;
    expect(q, contains('trashed=false'));
    expect(q, contains("appProperties has { key='$kAppPropertyKey' and value='$kAppPropertyValue' }"));
    expect(q, contains('application/vnd.google-apps.spreadsheet'));
  });

  test('getFile returns null for a missing file and for a trashed one', () async {
    wire.reply = (_) => {'id': 'x', 'name': 'SheetTick', 'trashed': true};
    expect(await backend.getFile('x'), isNull);

    final notFound = _Wire();
    final b = GoogleSheetsBackend(
      MockClient((_) async => http.Response(jsonEncode({'error': {'code': 404, 'message': 'nf'}}), 404,
          headers: {'content-type': 'application/json'})),
      sleep: (_) async {},
    );
    expect(await b.getFile('gone'), isNull);
    expect(notFound.requests, isEmpty);
  });

  test('trashFile moves to the trash, it does not delete', () async {
    await backend.trashFile('abc');
    expect(wire.last.method, 'PATCH');
    expect(wire.lastBody, {'trashed': true});
  });

  test('writeRanges is one raw batchUpdate; userEntered is opt-in', () async {
    await backend.writeRanges('s1', {
      'tasks!A2:C2': [
        ['=HYPERLINK("x")', 5, true],
      ],
      'lists!A3': [
        ['y'],
      ],
    });
    expect(wire.requests, hasLength(1));
    expect(wire.last.url.path, endsWith('/spreadsheets/s1/values:batchUpdate'));
    expect(wire.lastBody['valueInputOption'], 'RAW');
    expect((wire.lastBody['data'] as List).map((d) => d['range']), ['tasks!A2:C2', 'lists!A3']);

    await backend.writeRanges('s1', {
      'View!A1': [
        ['=1+1'],
      ],
    }, userEntered: true);
    expect(wire.lastBody['valueInputOption'], 'USER_ENTERED');
  });

  test('readRanges is one batchGet with unformatted values, and tolerates empty ranges', () async {
    wire.reply = (_) => {
      'valueRanges': [
        {
          'values': [
            ['id', 'title'],
            ['a', true],
          ],
        },
        <String, Object?>{},
      ],
    };
    final out = await backend.readRanges('s1', ['tasks!A:B', 'lists!1:1']);
    expect(wire.requests, hasLength(1));
    expect(wire.last.url.queryParametersAll['ranges'], ['tasks!A:B', 'lists!1:1']);
    expect(wire.last.url.queryParameters['valueRenderOption'], 'UNFORMATTED_VALUE');
    expect(out, [
      [
        ['id', 'title'],
        ['a', true],
      ],
      <List<Object?>>[],
    ]);
  });

  test('appendRows appends raw rows as new rows and reports where they landed', () async {
    wire.reply = (_) => {
      'updates': {'updatedRange': 'tasks!A5:AB6', 'updatedRows': 2},
    };
    final r = await backend.appendRows('s1', 'tasks', [
      ['a'],
      ['b'],
    ]);
    expect((r.firstRow, r.rowCount), (5, 2));
    expect(Uri.decodeComponent(wire.last.url.path), contains('values/tasks!A1:append'));
    expect(wire.last.url.queryParameters['valueInputOption'], 'RAW');
    expect(wire.last.url.queryParameters['insertDataOption'], 'INSERT_ROWS');
  });

  test('changeTabs adds tabs with a frozen header and plain-text columns, then removes, in one request', () async {
    wire.reply = (req) => req.url.path.endsWith(':batchUpdate')
        ? <String, Object?>{}
        : {
            'sheets': [
              {'properties': {'sheetId': 0, 'title': 'Sheet1'}},
            ],
          };

    await backend.changeTabs('s1', add: [tabSpec('lists'), kViewTab], removeSheetIds: [0]);

    final batch = wire.requests.where((r) => r.url.path.endsWith(':batchUpdate')).toList();
    expect(batch, hasLength(1));
    final requests = (jsonDecode(batch.single.body) as Map)['requests'] as List;
    final kinds = requests.map((r) => (r as Map).keys.single).toList();
    expect(kinds.first, 'addSheet');
    expect(kinds.last, 'deleteSheet'); // removal comes after additions

    final add = (requests.first as Map)['addSheet']['properties'] as Map;
    expect(add['title'], 'lists');
    expect(add['sheetId'], 1); // after the existing id 0
    expect(add['gridProperties']['frozenRowCount'], 1);
    expect(add['gridProperties']['columnCount'], tabSpec('lists').columns.length);

    final formats = requests
        .where((r) => (r as Map).containsKey('repeatCell'))
        .map((r) => (r as Map)['repeatCell'] as Map)
        .toList();
    expect(formats.any((f) => f['fields'] == 'userEnteredFormat.textFormat.bold'), isTrue);
    final plain = formats.where((f) => f['fields'] == 'userEnteredFormat.numberFormat').toList();
    expect(plain, isNotEmpty);
    expect(plain.every((f) => f['cell']['userEnteredFormat']['numberFormat']['type'] == 'TEXT'), isTrue);
    // Numeric/boolean columns (sort_order, is_inbox, version, deleted ...) are not forced to text.
    final lists = tabSpec('lists');
    final textColumns = <int>{};
    for (final f in plain) {
      final range = f['range'] as Map;
      for (var c = range['startColumnIndex'] as int; c < (range['endColumnIndex'] as int); c++) {
        textColumns.add(c);
      }
    }
    for (var i = 0; i < lists.columns.length; i++) {
      expect(textColumns.contains(i), lists.columns[i].type.isTextual, reason: lists.columns[i].name);
    }

    // The View tab is a plain tab: no frozen header.
    final view = (requests[requests.indexWhere((r) => (r as Map)['addSheet']?['properties']?['title'] == kViewTabName)]
        as Map)['addSheet']['properties'] as Map;
    expect(view['gridProperties']['frozenRowCount'], 0);
  });

  test('429 and 5xx are retried, other errors are not', () async {
    wire.failFirstWith = 429;
    wire.reply = (_) => {'id': 'abc', 'name': 'SheetTick'};
    final f = await backend.createSpreadsheet('SheetTick');
    expect(f.id, 'abc');
    expect(wire.requests, hasLength(2));

    final denied = GoogleSheetsBackend(
      MockClient((_) async => http.Response(jsonEncode({'error': {'code': 403, 'message': 'no'}}), 403,
          headers: {'content-type': 'application/json'})),
      sleep: (_) async {},
    );
    await expectLater(denied.createSpreadsheet('x'), throwsA(anything));
  });

  test('firstRowOfRange', () {
    expect(firstRowOfRange('tasks!A5:AB6'), 5);
    expect(firstRowOfRange('tasks!A12'), 12);
    expect(firstRowOfRange("'My Tab'!A1:C3"), 1);
    expect(() => firstRowOfRange('garbage'), throwsFormatException);
  });
}
