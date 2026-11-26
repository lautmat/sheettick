import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/tasks/priority.dart';
import 'package:sheettick/core/tasks/tags.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('tag names', () {
    test('a name is trimmed, loses a leading # and its commas, and blank is nothing', () {
      expect(cleanTagName('  #work  '), 'work');
      expect(cleanTagName('deep   focus'), 'deep focus');
      expect(cleanTagName('a,b'), 'a b');
      expect(cleanTagName(' # '), isNull);
      expect(cleanTagName(''), isNull);
    });

    test('a cell typed by hand reads cleanly: spaces, blanks and a repeat in another case are dropped', () {
      expect(parseTags('work, Home ,,#errands,WORK'), ['work', 'Home', 'errands']);
      expect(parseTags(''), isEmpty);
      expect(parseTags(null), isEmpty);
    });

    test('the cell is the names joined by commas', () {
      expect(formatTags(['work', 'deep focus']), 'work,deep focus');
      expect(parseTags(formatTags(['work', 'deep focus'])), ['work', 'deep focus']);
    });

    test('adding a tag already there in another case changes nothing; removing ignores case', () {
      expect(withTag(['Work'], 'work'), ['Work']);
      expect(withTag(['Work'], 'home'), ['Work', 'home']);
      expect(withoutTag(['Work', 'home'], 'WORK'), ['home']);
    });
  });

  group('priority', () {
    test('the four TickTick values, and a hand-typed value counts as the nearest one below it', () {
      expect(Priority.values.map((p) => p.value), [0, 1, 3, 5]);
      expect(Priority.of(5), Priority.high);
      expect(Priority.of(4), Priority.medium);
      expect(Priority.of(2), Priority.low);
      expect(Priority.of(0), Priority.none);
      expect(Priority.of(-3), Priority.none);
      expect(Priority.of(9), Priority.high);
    });
  });

  group('task tags in the database', () {
    late AppDatabase db;
    late LocalWriter writer;
    late String taskId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      writer = LocalWriter(DriftLocalStore(db), deviceId: 'win-test');
      taskId = await writer.insert('tasks', {'title': 'Call the bank'});
    });

    tearDown(() => db.close());

    Future<Task> task() => (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingle();
    Future<List<Tag>> tagRows() => db.select(db.tags).get();

    test('a new tag is stored on the task and gets one row in the tags tab, dirty for the next push', () async {
      expect(await addTaskTag(writer, taskId, ' #Finance '), 'Finance');

      final t = await task();
      expect(t.tags, 'Finance');
      expect(t.version, 2);
      expect(t.dirty, isTrue);
      final rows = await tagRows();
      expect(rows.map((r) => r.name), ['Finance']);
      expect(rows.single.dirty, isTrue);
      expect(rows.single.sortOrder, 1);
    });

    test('a tag the tags tab has, in any case, is reused with its spelling and gets no second row', () async {
      await writer.insert('tags', {'name': 'Finance', 'sort_order': 4.0});

      expect(await addTaskTag(writer, taskId, 'finance'), 'Finance');

      expect((await task()).tags, 'Finance');
      expect((await tagRows()).length, 1);
    });

    test('a deleted tag does not count: adding its name again makes a new row after the others', () async {
      final old = await writer.insert('tags', {'name': 'old', 'sort_order': 2.0});
      await writer.delete('tags', old);

      await addTaskTag(writer, taskId, 'old');

      final live = (await tagRows()).where((r) => !r.deleted).toList();
      expect(live.single.name, 'old');
      expect(live.single.sortOrder, 1);
    });

    test('adding reads the current tags, so a change made since (another device, the Sheet) is kept', () async {
      await writer.update('tasks', taskId, {'tags': 'home'});

      await addTaskTag(writer, taskId, 'work');

      expect((await task()).tags, 'home,work');
    });

    test('adding a tag the task has, or a blank one, writes nothing', () async {
      await addTaskTag(writer, taskId, 'work');
      final before = (await task()).version;

      expect(await addTaskTag(writer, taskId, 'WORK'), 'work');
      expect(await addTaskTag(writer, taskId, '  '), isNull);

      expect((await task()).version, before);
    });

    test('a tag added to several tasks: the ones without it change, each keeps its other tags, one tags row is made', () async {
      final a = await writer.insert('tasks', {'title': 'A', 'tags': 'home'});
      final b = await writer.insert('tasks', {'title': 'B', 'tags': 'Work,home'});

      final result = await addTagToTasks(writer, [taskId, a, b], ' #work ');

      expect(result?.name, 'work');
      expect(result?.changed, 2, reason: 'B has it already, in another case');
      expect((await task()).tags, 'work');
      expect((await (db.select(db.tasks)..where((t) => t.id.equals(a))).getSingle()).tags, 'home,work');
      final bRow = await (db.select(db.tasks)..where((t) => t.id.equals(b))).getSingle();
      expect(bRow.tags, 'Work,home');
      expect(bRow.version, 1);
      final rows = await tagRows();
      expect(rows.map((r) => r.name), ['work']);
      expect(result?.createdId, rows.single.id);
    });

    test('a tag the tags tab already has is reused with its spelling and makes no row', () async {
      await writer.insert('tags', {'name': 'Finance', 'sort_order': 4.0});

      final result = await addTagToTasks(writer, [taskId], 'finance');

      expect(result?.name, 'Finance');
      expect(result?.createdId, isNull);
      expect((await tagRows()).length, 1);
      expect((await task()).tags, 'Finance');
    });

    test('a blank tag is nothing', () async {
      expect(await addTagToTasks(writer, [taskId], '  # '), isNull);
      expect((await task()).version, 1);
      expect(await tagRows(), isEmpty);
    });

    test('removing takes the name off the task and leaves the tag in the tags tab', () async {
      await addTaskTag(writer, taskId, 'work');
      await addTaskTag(writer, taskId, 'home');

      await removeTaskTag(writer, taskId, 'Work');

      expect((await task()).tags, 'home');
      expect((await tagRows()).map((r) => r.name), containsAll(['work', 'home']));
    });
  });
}
