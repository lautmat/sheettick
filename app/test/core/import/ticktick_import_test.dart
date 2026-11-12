import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/import/ticktick_import.dart';

import '../../support/fake_sheets_backend.dart';
import '../../support/test_device.dart';

Map<String, Object?> task(String id, {Map<String, Object?> extra = const {}}) =>
    {'id': id, 'title': 'T $id', 'status': 0, ...extra};

PlannedRow only(ImportPlan p, String id) => p.rows.singleWhere((r) => r.id == importedId(id));

void main() {
  const inbox = 'inbox-1';
  ImportPlan plan(List<Map<String, Object?>> tasks) => planTickTickImport(jsonEncode({'tasks': tasks}), listId: inbox);

  test('an undated task has no dates', () {
    final f = only(plan([task('a')]), 'a').fields;
    expect(f['due_at'], isNull);
    expect(f['all_day'], false);
    expect(f['list_id'], inbox);
  });

  // The all-day date is the day in the task's own zone, whatever the offset of the text or the importing device.
  for (final c in const [
    ['Asia/Seoul', '2027-06-30T00:00:00+0900', '2027-06-30'],
    ['Europe/Lisbon', '2027-06-30T00:00:00+0100', '2027-06-30'],
    ['Africa/Kampala', '2027-06-30T00:00:00+0300', '2027-06-30'],
    ['Africa/Addis_Ababa', '2027-01-05T00:00:00+0300', '2027-01-05'],
    ['Europe/London', '2027-01-05T00:00:00+0000', '2027-01-05'],
    ['Asia/Qatar', '2027-03-01T00:00:00+0300', '2027-03-01'],
    ['Asia/Bangkok', '2027-03-01T00:00:00+0700', '2027-03-01'],
    ['Africa/Nairobi', '2027-12-31T00:00:00+0300', '2027-12-31'],
  ]) {
    test('all-day ${c[0]}', () {
      final f = only(plan([task('a', extra: {'dueDate': c[1], 'isAllDay': true, 'timeZone': c[0]})]), 'a').fields;
      expect(f['due_at'], c[2]);
      expect(f['all_day'], true);
      expect(f['tz'], isNull);
    });
  }

  test('an all-day date stored as the previous day in UTC still lands on its day', () {
    final f = only(plan([task('a', extra: {'dueDate': '2027-06-29T15:00:00+0000', 'isAllDay': true, 'timeZone': 'Asia/Seoul'})]), 'a').fields;
    expect(f['due_at'], '2027-06-30');
  });

  test('a timed task keeps its instant, offset and zone', () {
    final f = only(plan([task('a', extra: {'dueDate': '2027-01-05T09:30:00+0100', 'isAllDay': false, 'timeZone': 'Europe/Paris'})]), 'a').fields;
    expect(f['due_at'], '2027-01-05T09:30:00+01:00');
    expect(f['tz'], 'Europe/Paris');
    expect(f['all_day'], false);
  });

  test('repeat: 0, 2 and missing import as DUE, 1 as COMPLETION, and all are listed', () {
    final p = plan([
      task('a', extra: {'repeatFlag': 'RRULE:FREQ=DAILY', 'repeatFrom': '0'}),
      task('b', extra: {'repeatFlag': 'RRULE:FREQ=DAILY', 'repeatFrom': '2'}),
      task('c', extra: {'repeatFlag': 'RRULE:FREQ=DAILY', 'repeatFrom': '1'}),
      task('d', extra: {'repeatFlag': 'RRULE:FREQ=DAILY'}),
    ]);
    expect([for (final id in 'abcd'.split('')) only(p, id).fields['repeat_from']], ['DUE', 'DUE', 'COMPLETION', 'DUE']);
    expect(p.repeating, hasLength(4));
    expect(p.describe(), contains('Repeating tasks'));
  });

  test('subtasks point at their parent, parents come first, checklist items are mapped', () {
    final p = plan([
      task('child', extra: {'parentId': 'parent'}),
      task('parent', extra: {'items': [{'id': 'i1', 'title': 'x', 'status': 1, 'sortOrder': 3}]}),
    ]);
    final tasks = p.rows.where((r) => r.tab == 'tasks').toList();
    expect(tasks.first.id, importedId('parent'));
    expect(only(p, 'child').fields['parent_id'], importedId('parent'));
    final item = p.rows.singleWhere((r) => r.tab == 'checklist');
    expect(item.fields['task_id'], importedId('parent'));
    expect(item.fields['status'], 2);
  });

  test('notes, priority and non-open tasks', () {
    final p = plan([task('a', extra: {'content': '# hi', 'priority': 5}), task('b', extra: {'status': 2})]);
    expect(only(p, 'a').fields['content'], '# hi');
    expect(only(p, 'a').fields['priority'], 5);
    expect(p.taskCount, 1);
    expect(p.warnings.single, contains('Skipped'));
  });

  test('applying twice writes once', () async {
    final device = await TestDevice.create(FakeSheetsBackend());
    addTearDown(device.close);
    final p = planTickTickImport(
      jsonEncode([task('parent'), task('child', extra: {'parentId': 'parent', 'dueDate': '2027-06-30T00:00:00+0900', 'isAllDay': true, 'timeZone': 'Asia/Seoul'})]),
      listId: device.inboxId,
    );
    final first = await applyTickTickImport(device.writer, p);
    final second = await applyTickTickImport(device.writer, p);
    expect((first.written, first.skipped), (2, 0));
    expect((second.written, second.skipped), (0, 2));
    final row = await device.task(importedId('child'));
    expect(row.fields['due_at'], '2027-06-30');
    expect(row.fields['parent_id'], importedId('parent'));
    expect(row.dirty, true);
  });
}
