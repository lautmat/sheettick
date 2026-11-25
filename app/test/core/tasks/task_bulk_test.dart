import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/tasks/task_bulk.dart';
import 'package:sheettick/core/undo/undo.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late LocalWriter writer;
  late String inbox;
  late String work;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    writer = LocalWriter(DriftLocalStore(db), deviceId: 'win-test');
    inbox = await writer.insert('lists', {'name': 'Inbox', 'is_inbox': true});
    work = await writer.insert('lists', {'name': 'Work'});
  });

  tearDown(() => db.close());

  Future<String> add(String title, {String? list, Map<String, Object?> more = const {}}) =>
      writer.insert('tasks', {'list_id': list ?? inbox, 'title': title, ...more});

  Future<Task> task(String id) => (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();

  /// Titles of the live top-level tasks of [list], in the order the list shows them.
  Future<List<String>> shown(String list) async {
    final rows = await (db.select(db.tasks)
          ..where((t) => t.listId.equals(list) & t.deleted.equals(false) & t.parentId.isNull()))
        .get();
    rows.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.createdAt.compareTo(b.createdAt);
    });
    return [for (final t in rows) t.title];
  }

  group('hiddenByFolding', () {
    test('hides the tasks of a folded section and the subtasks under them', () async {
      final a = await add('A', more: {'section_id': 's1'});
      final sub = await add('Sub of A', more: {'parent_id': a});
      final b = await add('B', more: {'section_id': 's2'});
      final loose = await add('Loose');
      final tasks = await db.select(db.tasks).get();

      expect(hiddenByFolding(tasks, {'s1'}), {a, sub});
      expect(hiddenByFolding(tasks, {'s1', 's2'}), {a, sub, b});
      expect(hiddenByFolding(tasks, {}), isEmpty);
      expect(hiddenByFolding(tasks, {'s1'}).contains(loose), isFalse);
    });

    test('a subtask follows its top-level task, not its own section_id', () async {
      final a = await add('A', more: {'section_id': 's1'});
      final sub = await add('Sub', more: {'parent_id': a, 'section_id': 's2'});
      final tasks = await db.select(db.tasks).get();

      expect(hiddenByFolding(tasks, {'s2'}), isEmpty, reason: 'it is shown under A, in s1');
      expect(hiddenByFolding(tasks, {'s1'}), {a, sub});
    });

    test('a cycle of parents does not loop', () async {
      final a = await add('A', more: {'section_id': 's1'});
      final b = await add('B', more: {'parent_id': a});
      await writer.update('tasks', a, {'parent_id': b});
      final tasks = await db.select(db.tasks).get();

      expect(hiddenByFolding(tasks, {'s1'}), isA<Set<String>>());
    });
  });

  group('withSubtasks', () {
    test('adds the subtasks at every depth, once, and leaves out deleted ones', () async {
      final a = await add('A');
      final b = await add('B', more: {'parent_id': a});
      final c = await add('C', more: {'parent_id': b});
      final gone = await add('Gone', more: {'parent_id': a});
      await writer.delete('tasks', gone);
      final other = await add('Other');

      final ids = await withSubtasks(writer, [a]);

      expect(ids.toSet(), {a, b, c});
      expect(ids.length, 3);
      expect(ids, isNot(contains(other)));
    });
  });

  group('moveTasksToListEnd', () {
    test('puts the tasks at the end of the list in the order given, and takes their subtasks along', () async {
      final existing = await add('Existing', list: work);
      final a = await add('A');
      final sub = await add('Sub of A', more: {'parent_id': a});
      final b = await add('B');
      final c = await add('C');

      final moved = await moveTasksToListEnd(writer, [c, a, b], work);

      expect(moved, 3);
      expect(await shown(work), ['Existing', 'C', 'A', 'B']);
      expect((await task(sub)).listId, work);
      expect((await task(sub)).parentId, a);
      expect(await shown(inbox), isEmpty);
      expect((await task(existing)).version, 1, reason: 'the tasks already there are not rewritten');
      expect((await task(a)).version, greaterThan(1), reason: 'a write through the local writer, so it syncs');
    });

    test('takes the section off a task and puts it outside any section', () async {
      final a = await add('A', more: {'section_id': 'some-section'});

      await moveTasksToListEnd(writer, [a], work);

      expect((await task(a)).sectionId, isNull);
    });

    test('a selected subtask whose parent is selected too follows the parent and stays its subtask', () async {
      final parent = await add('Parent');
      final child = await add('Child', more: {'parent_id': parent});

      final moved = await moveTasksToListEnd(writer, [parent, child], work);

      expect(moved, 1);
      expect((await task(child)).parentId, parent);
      expect((await task(child)).listId, work);
    });

    test('a selected subtask alone becomes a task of its own in the new list', () async {
      final parent = await add('Parent');
      final child = await add('Child', more: {'parent_id': parent});

      await moveTasksToListEnd(writer, [child], work);

      expect((await task(child)).parentId, isNull);
      expect((await task(child)).listId, work);
      expect((await task(parent)).listId, inbox);
    });

    test('a task already in the list is left where it is', () async {
      final a = await add('A', list: work);
      final b = await add('B', list: work);

      final moved = await moveTasksToListEnd(writer, [a], work);

      expect(moved, 0);
      expect(await shown(work), ['A', 'B']);
      expect((await task(a)).version, 1);
      expect((await task(b)).version, 1);
    });

    test('one undo puts every moved row back', () async {
      final a = await add('A');
      final sub = await add('Sub', more: {'parent_id': a});
      final b = await add('B');
      await add('Existing', list: work);

      final rows = await bulkMoveRows(writer, [a, b], work);
      final entry = await recordUndo(writer, 'Moved', rows, () async {
        await moveTasksToListEnd(writer, [a, b], work);
        return const [];
      });
      expect(entry, isNotNull);
      expect((await task(sub)).listId, work);

      await applyUndo(writer, entry!);

      expect((await task(a)).listId, inbox);
      expect((await task(b)).listId, inbox);
      expect((await task(sub)).listId, inbox);
      expect(await shown(inbox), ['A', 'B']);
    });
  });

  group('trashTasks', () {
    test('tombstones the tasks and their subtasks, and no others', () async {
      final a = await add('A');
      final sub = await add('Sub', more: {'parent_id': a});
      final b = await add('B');
      final keep = await add('Keep');

      final trashed = await trashTasks(writer, [a, b]);

      expect(trashed, 3);
      expect((await task(a)).deleted, isTrue);
      expect((await task(sub)).deleted, isTrue);
      expect((await task(b)).deleted, isTrue);
      expect((await task(keep)).deleted, isFalse);
      expect((await task(keep)).version, 1);
      expect((await task(a)).version, 2, reason: 'a tombstone is a write, so it syncs');
    });

    test('a task already in the Trash is not written again', () async {
      final a = await add('A');
      await writer.delete('tasks', a);

      expect(await trashTasks(writer, [a]), 0);
      expect((await task(a)).version, 2);
    });
  });
}
