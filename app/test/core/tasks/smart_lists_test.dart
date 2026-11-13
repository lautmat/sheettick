import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/tasks/smart_lists.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // Wednesday 11 November 2026, 11:00 in Paris.
  final now = DateTime.utc(2026, 11, 11, 10);
  const paris = 'Europe/Paris';

  late AppDatabase db;
  late LocalWriter writer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    writer = LocalWriter(DriftLocalStore(db), deviceId: 'win-test');
  });

  tearDown(() => db.close());

  Future<Task> add(String title, {Map<String, Object?> fields = const {}, bool trashed = false}) async {
    final id = await writer.insert('tasks', {'title': title, ...fields});
    if (trashed) await writer.delete('tasks', id);
    return (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<Set<SmartList>> listsOf(Task t, {DateTime? at, String? zone = paris}) async => {
    for (final l in SmartList.values)
      if (smartListHas(l, t, now: at ?? now, zone: zone)) l,
  };

  test('a task with no date is in All and No Date, and in no date list', () async {
    expect(await listsOf(await add('Plain')), {SmartList.all, SmartList.noDate});
  });

  test('No Date holds open tasks with neither a start nor a due, from every list', () async {
    expect(await listsOf(await add('in a list', fields: {'list_id': 'some-list'})), contains(SmartList.noDate));
    expect(await listsOf(await add('due', fields: {'due_at': '2026-12-01', 'all_day': true})), isNot(contains(SmartList.noDate)));
    expect(await listsOf(await add('start', fields: {'start_at': '2026-12-01', 'all_day': true})), isNot(contains(SmartList.noDate)));
    expect(
      await listsOf(await add('timed', fields: {'due_at': '2026-12-01T09:00:00+01:00', 'tz': paris})),
      isNot(contains(SmartList.noDate)),
    );
  });

  test('No Date leaves out done, dropped and trashed tasks', () async {
    expect(await listsOf(await add('done', fields: {'status': 2})), isNot(contains(SmartList.noDate)));
    expect(await listsOf(await add('dropped', fields: {'status': -1})), isNot(contains(SmartList.noDate)));
    expect(await listsOf(await add('gone', trashed: true)), isNot(contains(SmartList.noDate)));
  });

  test('text that is not a date reads as no date, so the task is in No Date where it can be fixed', () async {
    final t = await add('odd', fields: {'due_at': 'next friday'});
    expect(await listsOf(t), {SmartList.all, SmartList.noDate});
  });

  test('No Date shows its rows in the order given, dated and closed tasks left out', () async {
    final first = await add('first');
    final dated = await add('dated', fields: {'due_at': '2026-11-11', 'all_day': true});
    final done = await add('done', fields: {'status': 2});
    final second = await add('second');
    final rows = smartListRows(SmartList.noDate, [first, dated, done, second], now: now, zone: paris);
    expect(rows.map((t) => t.title), ['first', 'second']);
  });

  test('the date lists go by the due day: overdue and today are Today, tomorrow is Tomorrow', () async {
    Future<Set<SmartList>> due(String day) async => listsOf(await add('t', fields: {'due_at': day, 'all_day': true}));
    expect(await due('2026-11-09'), {SmartList.all, SmartList.today});
    expect(await due('2026-11-11'), {SmartList.all, SmartList.today, SmartList.next7Days});
    expect(await due('2026-11-12'), {SmartList.all, SmartList.tomorrow, SmartList.next7Days});
    expect(await due('2026-11-17'), {SmartList.all, SmartList.next7Days});
    expect(await due('2026-11-18'), {SmartList.all});
  });

  test('a task with only a start is placed by its start; a due wins over the start', () async {
    final startOnly = await add('s', fields: {'start_at': '2026-11-12', 'all_day': true});
    expect(await listsOf(startOnly), {SmartList.all, SmartList.tomorrow, SmartList.next7Days});
    final both = await add('b', fields: {'start_at': '2026-11-10', 'due_at': '2026-11-12', 'all_day': true});
    expect(await listsOf(both), {SmartList.all, SmartList.tomorrow, SmartList.next7Days});
  });

  test('a timed due is read on the device zone, so the day depends on where the device is', () async {
    // 23:30 in Paris on the 11th is 22:30 UTC, and is the 12th in Auckland.
    final t = await add('t', fields: {'due_at': '2026-11-11T23:30:00+01:00', 'tz': paris});
    expect(await listsOf(t, zone: paris), contains(SmartList.today));
    expect(await listsOf(t, zone: 'Pacific/Auckland'), contains(SmartList.tomorrow));
  });

  test('"today" is where the device is: just after midnight in Paris is still the evening before in New York', () async {
    final late = DateTime.utc(2026, 11, 11, 23, 30);
    final t = await add('t', fields: {'due_at': '2026-11-12', 'all_day': true});
    expect(await listsOf(t, at: late, zone: paris), contains(SmartList.today));
    expect(await listsOf(t, at: late, zone: 'America/New_York'), contains(SmartList.tomorrow));
  });

  test('completed, won\'t do and trashed tasks are each only in their own list', () async {
    final dated = {'due_at': '2026-11-11', 'all_day': true};
    final done = await add('done', fields: {'status': 2, 'completed_at': '2026-11-10T08:00:00Z', ...dated});
    final dropped = await add('dropped', fields: {'status': -1, ...dated});
    final gone = await add('gone', fields: dated, trashed: true);
    final goneDone = await add('goneDone', fields: {'status': 2, ...dated}, trashed: true);
    expect(await listsOf(done), {SmartList.completed});
    expect(await listsOf(dropped), {SmartList.wontDo});
    expect(await listsOf(gone), {SmartList.trash});
    expect(await listsOf(goneDone), {SmartList.trash});
  });

  test('rows come back in each list\'s order', () async {
    final later = await add('later', fields: {'due_at': '2026-11-13', 'all_day': true});
    final earlier = await add('earlier', fields: {'due_at': '2026-11-11', 'all_day': true});
    final overdue = await add('overdue', fields: {'due_at': '2026-11-02', 'all_day': true});
    final order = smartListRows(SmartList.next7Days, [later, earlier, overdue], now: now, zone: paris);
    expect(order.map((t) => t.title), ['earlier', 'later']);

    final old = await add('old', fields: {'status': 2, 'completed_at': '2026-11-01T08:00:00Z'});
    final recent = await add('recent', fields: {'status': 2, 'completed_at': '2026-11-10T08:00:00Z'});
    expect(smartListRows(SmartList.completed, [old, recent], now: now).map((t) => t.title), ['recent', 'old']);
  });
}
