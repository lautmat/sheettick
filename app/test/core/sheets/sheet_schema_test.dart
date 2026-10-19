import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/sheets/sheet_schema.dart';

import '../../support/schema_doc.dart';

void main() {
  final doc = SchemaDoc();

  test('the tabs are exactly the documented ones, in order (View is formula-only)', () {
    expect([...kTabs.map((t) => t.name), kViewTabName], doc.tabNames.where((n) => n != 'Sync columns'));
  });

  test('sync columns match the doc', () {
    expect(kSyncColumns.map((c) => c.name), doc.syncColumns);
  });

  for (final tab in kTabs) {
    test('tab ${tab.name}: columns match the doc, in order, with sync columns last', () {
      final expected = [...doc.tabColumns(tab.name), if (tab.hasSyncColumns) ...doc.syncColumns];
      expect(tab.columnNames, expected);
    });
  }

  test('only meta lacks sync columns, and no column name repeats within a tab', () {
    expect(kTabs.where((t) => !t.hasSyncColumns).map((t) => t.name), ['meta']);
    for (final t in kTabs) {
      expect(t.columnNames.toSet().length, t.columnNames.length, reason: t.name);
    }
  });

  test('schema version matches the doc header', () {
    expect(doc.schemaVersion, kSheetSchemaVersion);
  });

  test('columnLetter', () {
    expect(columnLetter(0), 'A');
    expect(columnLetter(25), 'Z');
    expect(columnLetter(26), 'AA');
    expect(columnLetter(27), 'AB');
    expect(columnLetter(51), 'AZ');
    expect(columnLetter(52), 'BA');
    expect(columnLetter(701), 'ZZ');
    expect(columnLetter(702), 'AAA');
  });

  test('viewFormula points at the right tasks columns', () {
    final cols = tabSpec('tasks').columnNames;
    String at(String n) => columnLetter(cols.indexOf(n));
    final f = viewFormula();
    expect(f, startsWith('=QUERY(tasks!A:${columnLetter(cols.length - 1)}, "select ${at('title')}, ${at('due_at')}'));
    expect(f, contains('where ${at('deleted')} = FALSE and ${at('status')} = 0'));
    expect(f, endsWith('order by ${at('due_at')}", 1)'));
  });

  test('textual column types are plain-text formatted, numbers and booleans are not', () {
    expect(ColumnType.datetime.isTextual, isTrue);
    expect(ColumnType.timestamp.isTextual, isTrue);
    expect(ColumnType.uuid.isTextual, isTrue);
    expect(ColumnType.integer.isTextual, isFalse);
    expect(ColumnType.number.isTextual, isFalse);
    expect(ColumnType.boolean.isTextual, isFalse);
  });
}
