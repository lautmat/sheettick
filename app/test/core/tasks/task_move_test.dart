import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/tasks/task_move.dart';
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

  /// Titles of the top-level tasks of [list] in [section], in the order the list shows them.
  Future<List<String>> shown(String list, {String? section}) async {
    final rows = await (db.select(db.tasks)
          ..where((t) => t.listId.equals(list) & t.deleted.equals(false) & t.parentId.isNull()))
        .get();
    final inSection = rows.where((t) => t.sectionId == section).toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.createdAt.compareTo(b.createdAt);
      });
    return [for (final t in inSection) t.title];
  }

  Future<void> move(String id, {required String list, String? section, String? before}) async {
    final plan = await planMove(writer, id, listId: list, sectionId: section, beforeId: before);
    await applyMove(writer, plan);
  }

  test('dragging into a run of tasks that share a number numbers them, then one task moves at a time', () async {
    final a = await add('A');
    final b = await add('B');
    final c = await add('C');
    expect(await shown(inbox), ['A', 'B', 'C']);

    await move(c, list: inbox, before: b);
    expect(await shown(inbox), ['A', 'C', 'B']);
    // No number fits between two equal ones, so the three were numbered. Every write is a new version, so it syncs.
    expect((await task(a)).version, greaterThan(1));
    expect((await task(b)).version, greaterThan(1));
    expect((await task(c)).version, greaterThan(1));

    // From then on a number fits between the neighbours: one task is written and the others are left alone.
    final before = (await task(a)).version;
    await move(b, list: inbox, before: a);
    expect(await shown(inbox), ['B', 'A', 'C']);
    expect((await task(a)).version, before);
  });

  test('dropping a task where it already is writes nothing', () async {
    final a = await add('A');
    await add('B');
    final plan = await planMove(writer, a, listId: inbox, beforeId: null);
    expect(plan.isEmpty, isFalse, reason: 'A goes to the end');
    final b = (await db.select(db.tasks).get()).firstWhere((t) => t.title == 'B').id;
    expect((await planMove(writer, b, listId: inbox)).isEmpty, isTrue, reason: 'B is already last');
    expect((await planMove(writer, a, listId: inbox, beforeId: b)).isEmpty, isTrue, reason: 'A is already before B');
  });

  test('moving to a section sets it, and the task is placed among that section\'s tasks', () async {
    final s = await writer.insert('sections', {'list_id': inbox, 'name': 'Home'});
    final a = await add('A', more: {'section_id': s, 'sort_order': 1});
    final b = await add('B', more: {'section_id': s, 'sort_order': 2});
    final loose = await add('Loose');

    await move(loose, list: inbox, section: s, before: b);

    expect(await shown(inbox, section: s), ['A', 'Loose', 'B']);
    expect((await task(loose)).sectionId, s);
    expect((await task(a)).version, 1, reason: 'a number fitted between the neighbours');
  });

  test('moving out of a section, and a section that is gone counts as no section', () async {
    final live = await writer.insert('sections', {'list_id': inbox, 'name': 'Home'});
    final gone = await writer.insert('sections', {'list_id': inbox, 'name': 'Old'});
    await writer.delete('sections', gone);
    final x = await add('X', more: {'section_id': gone, 'sort_order': 1});
    final y = await add('Y', more: {'section_id': live, 'sort_order': 1});

    // X is shown outside any section, so Y dropped before it lands first there.
    await move(y, list: inbox, section: null, before: x);

    expect((await task(y)).sectionId, isNull);
    expect(await shown(inbox, section: null), contains('Y'));
    final unsectioned = await db.select(db.tasks).get();
    final order = {for (final t in unsectioned) t.title: t.sortOrder};
    expect(order['Y']!, lessThan(order['X']!));
  });

  test('moving to another list takes the section off and the subtasks along', () async {
    final s = await writer.insert('sections', {'list_id': inbox, 'name': 'Home'});
    final parent = await add('Parent', more: {'section_id': s});
    final child = await add('Child', more: {'parent_id': parent});
    final grandchild = await add('Grandchild', more: {'parent_id': child});
    final other = await add('Other');

    await move(parent, list: work);

    final p = await task(parent);
    expect(p.listId, work);
    expect(p.sectionId, isNull);
    expect((await task(child)).listId, work);
    expect((await task(child)).parentId, parent, reason: 'the subtask stays under its parent');
    expect((await task(grandchild)).listId, work);
    expect((await task(other)).listId, inbox);
    expect(await shown(work), ['Parent']);
  });

  test('a moved task is undone by putting list, section and order back', () async {
    final s = await writer.insert('sections', {'list_id': inbox, 'name': 'Home'});
    final a = await add('A', more: {'section_id': s});
    final child = await add('Child', more: {'parent_id': a});
    final plan = await planMove(writer, a, listId: work);

    final entry = await recordUndo(writer, 'Task moved', plan.rows, () async {
      await applyMove(writer, plan);
      return const [];
    });
    expect((await task(a)).listId, work);
    expect((await task(child)).listId, work);

    await applyUndo(writer, entry!);
    expect((await task(a)).listId, inbox);
    expect((await task(a)).sectionId, s);
    expect((await task(child)).listId, inbox);
  });

  test('open tasks come before done ones, as the list shows them', () async {
    final open1 = await add('Open1', more: {'sort_order': 5});
    await add('Done', more: {'status': 2, 'sort_order': 1});
    final open2 = await add('Open2', more: {'sort_order': 6});

    await move(open2, list: inbox, before: open1);

    // Tasks are ordered by status, then number: the open ones in the new order, the done one after them.
    final rows = await (db.select(db.tasks)
          ..orderBy([(t) => OrderingTerm.asc(t.status), (t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    expect([for (final t in rows) t.title], ['Open2', 'Open1', 'Done']);
  });
}
