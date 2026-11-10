import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/tasks/task_order.dart';
import 'package:sheettick/core/tasks/task_tree.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // Wednesday 11 November 2026, 11:00 in Paris.
  final now = DateTime.utc(2026, 11, 11, 10);
  const paris = 'Europe/Paris';

  late AppDatabase db;
  late LocalWriter writer;
  var clock = DateTime.utc(2026, 1, 1);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = DateTime.utc(2026, 1, 1);
    // Each task is made a minute after the one before, so `created_at` follows the order they are added in.
    writer = LocalWriter(DriftLocalStore(db), deviceId: 'win-test', clock: () => clock = clock.add(const Duration(minutes: 1)));
  });

  tearDown(() => db.close());

  Future<Task> add(String title, [Map<String, Object?> fields = const {}]) async {
    final id = await writer.insert('tasks', {'title': title, ...fields});
    return (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();
  }

  List<String> titles(Iterable<Task> tasks) => [for (final t in tasks) t.title];

  group('sortTasks', () {
    test('manual keeps the order given', () async {
      final tasks = [await add('b'), await add('a'), await add('c')];
      expect(titles(sortTasks(tasks, TaskOrder.manual)), ['b', 'a', 'c']);
    });

    test('due date: earliest first, by due else start, and no date last', () async {
      final none = await add('none');
      final late = await add('late', {'due_at': '2026-11-20', 'all_day': true});
      final soon = await add('soon', {'due_at': '2026-11-12', 'all_day': true});
      final starts = await add('starts', {'start_at': '2026-11-15', 'all_day': true});
      expect(titles(sortTasks([none, late, soon, starts], TaskOrder.due, zone: paris)), [
        'soon',
        'starts',
        'late',
        'none',
      ]);
    });

    test('priority: high first, ties keep their manual order', () async {
      final low = await add('low', {'priority': 1});
      final high1 = await add('high1', {'priority': 5});
      final none = await add('none');
      final high2 = await add('high2', {'priority': 5});
      final medium = await add('medium', {'priority': 3});
      expect(titles(sortTasks([low, high1, none, high2, medium], TaskOrder.priority)), [
        'high1',
        'high2',
        'medium',
        'low',
        'none',
      ]);
    });

    test('created: newest first', () async {
      final first = await add('first');
      final second = await add('second');
      final third = await add('third');
      expect(titles(sortTasks([first, second, third], TaskOrder.created)), ['third', 'second', 'first']);
    });

    test('title: A to Z ignoring case', () async {
      final tasks = [await add('banana'), await add('Apple'), await add('cherry')];
      expect(titles(sortTasks(tasks, TaskOrder.title)), ['Apple', 'banana', 'cherry']);
    });

    test('done tasks stay behind the open ones whatever the sort', () async {
      final done = await add('a done', {'status': 2});
      final open = await add('z open');
      expect(titles(sortTasks([done, open], TaskOrder.title)), ['z open', 'a done']);
    });

    test("won't-do tasks (status -1) also stay behind the open ones", () async {
      final dropped = await add('a dropped', {'status': -1});
      final open = await add('z open');
      expect(titles(sortTasks([dropped, open], TaskOrder.title)), ['z open', 'a dropped']);
      expect(titles(sortTasks([dropped, open], TaskOrder.priority)), ['z open', 'a dropped']);
    });
  });

  group('groupRows', () {
    List<({Task item, int depth})> arrange(List<Task> tasks) =>
        arrangeTree(tasks, idOf: (t) => t.id, parentOf: (t) => t.parentId);

    Map<String, List<String>> grouped(List<Task> tasks, TaskGroup group, {Map<String, String> listNames = const {}}) => {
      for (final g in groupRows(arrange(tasks), group, now: now, zone: paris, listNames: listNames))
        g.label: [for (final r in g.rows) r.item.title],
    };

    test('none is one group with no label', () async {
      final tasks = [await add('a'), await add('b')];
      expect(grouped(tasks, TaskGroup.none), {'': ['a', 'b']});
    });

    test('due date: Overdue, Today, Tomorrow, Next 7 Days, Later, No date, only the ones with tasks', () async {
      final tasks = [
        await add('none'),
        await add('later', {'due_at': '2026-12-25', 'all_day': true}),
        await add('week', {'due_at': '2026-11-18', 'all_day': true}),
        await add('tomorrow', {'due_at': '2026-11-12', 'all_day': true}),
        await add('today', {'due_at': '2026-11-11', 'all_day': true}),
        await add('overdue', {'due_at': '2026-11-01', 'all_day': true}),
      ];
      final groups = grouped(tasks, TaskGroup.due);
      expect(groups.keys.toList(), ['Overdue', 'Today', 'Tomorrow', 'Next 7 Days', 'Later', 'No date']);
      expect(groups['Next 7 Days'], ['week']);
      expect(grouped([tasks[3]], TaskGroup.due).keys, ['Tomorrow']);
    });

    test('priority: High, Medium, Low, None', () async {
      final tasks = [
        await add('n'),
        await add('l', {'priority': 1}),
        await add('h', {'priority': 5}),
        await add('m', {'priority': 3}),
      ];
      expect(grouped(tasks, TaskGroup.priority), {'High': ['h'], 'Medium': ['m'], 'Low': ['l'], 'None': ['n']});
    });

    test('tag: one group per tag A to Z, a task with two tags is in both, No tag last', () async {
      final tasks = [
        await add('plain'),
        await add('both', {'tags': 'work,home'}),
        await add('work only', {'tags': 'work'}),
      ];
      expect(grouped(tasks, TaskGroup.tag), {
        'home': ['both'],
        'work': ['both', 'work only'],
        'No tag': ['plain'],
      });
    });

    test('list: one group per list name, A to Z', () async {
      final inbox = await writer.insert('lists', {'name': 'Inbox'});
      final work = await writer.insert('lists', {'name': 'Work'});
      final tasks = [
        await add('a', {'list_id': work}),
        await add('b', {'list_id': inbox}),
        await add('c', {'list_id': work}),
      ];
      expect(grouped(tasks, TaskGroup.list, listNames: {inbox: 'Inbox', work: 'Work'}), {
        'Inbox': ['b'],
        'Work': ['a', 'c'],
      });
    });

    test('a subtask goes with its parent, into every group the parent is in', () async {
      final parent = await add('parent', {'priority': 5, 'tags': 'x,y'});
      final child = await add('child', {'parent_id': parent.id});
      final other = await add('other');
      final byPriority = grouped([parent, child, other], TaskGroup.priority);
      expect(byPriority, {'High': ['parent', 'child'], 'None': ['other']});
      expect(grouped([parent, child, other], TaskGroup.tag), {
        'x': ['parent', 'child'],
        'y': ['parent', 'child'],
        'No tag': ['other'],
      });
    });
  });

  test('the stored text maps to the choice, and anything else is the default', () {
    expect(TaskOrder.of('due'), TaskOrder.due);
    expect(TaskOrder.of(null), TaskOrder.manual);
    expect(TaskOrder.of('nonsense'), TaskOrder.manual);
    expect(TaskGroup.of('tag'), TaskGroup.tag);
    expect(TaskGroup.of(''), TaskGroup.none);
    expect(TaskGroup.of('nonsense'), TaskGroup.none);
  });
}
