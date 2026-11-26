import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/tasks/task_duplicate.dart';
import 'package:sheettick/core/tasks/task_pin.dart';
import 'package:sheettick/core/undo/undo.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late LocalWriter writer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    writer = LocalWriter(DriftLocalStore(db), deviceId: 'win-test');
  });

  tearDown(() => db.close());

  Future<String> add(String title, [Map<String, Object?> fields = const {}]) =>
      writer.insert('tasks', {'list_id': 'L', 'title': title, ...fields});

  Future<Task> get(String id) => (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();

  Future<List<Task>> live() async => (await db.select(db.tasks).get()).where((t) => !t.deleted).toList();

  /// The titles of the live tasks under [parent], in their order.
  Future<List<String>> titles({String? parent}) async {
    final rows = (await live()).where((t) => t.parentId == parent).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [for (final t in rows) t.title];
  }

  test('the copy keeps the content, is open and unpinned, and has a new id', () async {
    final id = await add('Pay rent', {
      'content': 'IBAN in the folder',
      'priority': 5,
      'tags': 'home',
      'due_at': '2026-11-30',
      'all_day': true,
      'rrule': 'RRULE:FREQ=MONTHLY',
      'reminders': '["TRIGGER:PT9H"]',
      'status': 2,
      'completed_at': '2026-11-01T10:00:00Z',
      'pinned_at': '2026-11-01T10:00:00Z',
    });

    final made = await duplicateTask(writer, id);

    expect(made.single.tab, 'tasks');
    expect(made.single.id, isNot(id));
    final copy = await get(made.single.id);
    expect(
      [copy.title, copy.content, copy.priority, copy.tags, copy.dueAt, copy.allDay, copy.rrule, copy.reminders, copy.listId],
      ['Pay rent', 'IBAN in the folder', 5, 'home', '2026-11-30', true, 'RRULE:FREQ=MONTHLY', '["TRIGGER:PT9H"]', 'L'],
    );
    expect([copy.status, copy.completedAt, copy.pinnedAt, copy.dirty], [0, null, null, true]);
    expect((await get(id)).status, 2, reason: 'the original is as it was');
  });

  test('subtasks at every depth and checklist items come along, open and in order', () async {
    final root = await add('Trip');
    final first = await add('Book', {'parent_id': root, 'sort_order': 1.0, 'status': 2});
    await add('Pack', {'parent_id': root, 'sort_order': 2.0});
    await add('Flights', {'parent_id': first});
    final dropped = await add('Dropped', {'parent_id': root, 'sort_order': 3.0, 'status': -1});
    await add('Under dropped', {'parent_id': dropped});
    final trashed = await add('Trashed', {'parent_id': root});
    await writer.delete('tasks', trashed);
    await writer.insert('checklist', {'task_id': root, 'title': 'b', 'sort_order': 2.0, 'status': 0});
    await writer.insert('checklist', {'task_id': root, 'title': 'a', 'sort_order': 1.0, 'status': 2});
    await writer.insert('checklist', {'task_id': first, 'title': 'c', 'sort_order': 1.0});

    final made = await duplicateTask(writer, root);
    final copy = made.first.id;

    expect(await titles(parent: copy), ['Book', 'Pack']);
    final book = (await live()).singleWhere((t) => t.parentId == copy && t.title == 'Book');
    expect(book.status, 0);
    expect(await titles(parent: book.id), ['Flights']);
    final items = (await db.select(db.checklist).get()).where((i) => i.taskId == copy).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    expect([for (final i in items) '${i.title}:${i.status}'], ['a:0', 'b:0']);
    expect((await db.select(db.checklist).get()).where((i) => i.taskId == book.id).single.title, 'c');
    expect(made.where((r) => r.tab == 'tasks'), hasLength(4));
    expect(made.where((r) => r.tab == 'checklist'), hasLength(3));
  });

  test('the copy sits just below the original, whether there is room between the neighbours or not', () async {
    final a = await add('A', {'sort_order': 1.0});
    await add('B', {'sort_order': 2.0});
    await duplicateTask(writer, a);
    expect(await titles(), ['A', 'A', 'B']);

    for (final t in await live()) {
      await writer.delete('tasks', t.id);
    }
    // New tasks all have the same sort_order, so the list is renumbered to make room.
    final x = await add('X');
    await add('Y');
    await add('Z');
    final shownBefore = await titles();
    final made = await duplicateTask(writer, x);
    final after = (await live())..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final at = after.indexWhere((t) => t.id == x);
    expect(after[at + 1].id, made.first.id);
    expect(shownBefore, hasLength(3));
  });

  test('one Undo removes everything the copy made and puts the order back', () async {
    final x = await add('X');
    final y = await add('Y');
    await add('Child', {'parent_id': x});
    await writer.insert('checklist', {'task_id': x, 'title': 'item'});
    final rows = await duplicateRows(writer, x);

    final undo = await recordUndo(writer, 'Task duplicated', rows, () => duplicateTask(writer, x));
    await applyUndo(writer, undo!);

    expect((await live()).map((t) => t.title).toList()..sort(), ['Child', 'X', 'Y']);
    expect((await get(x)).sortOrder, 0);
    expect((await get(y)).sortOrder, 0);
    expect((await db.select(db.checklist).get()).where((i) => !i.deleted).single.taskId, x);
  });

  test('pinning stamps pinned_at, unpinning clears it; a completed or buried task is not at the head', () async {
    final top = await add('Top');
    final child = await add('Child', {'parent_id': top});
    final done = await add('Done', {'status': 2});
    final now = DateTime.utc(2026, 11, 26, 9, 30);

    await setPinned(writer, top, true, now: now);
    await setPinned(writer, done, true, now: now);

    expect((await get(top)).pinnedAt, '2026-11-26T09:30:00Z');
    expect(underPinned(await live()), {top, child});

    await setPinned(writer, top, false, now: now);
    expect((await get(top)).pinnedAt, isNull);
    expect(underPinned(await live()), isEmpty);
  });
}
