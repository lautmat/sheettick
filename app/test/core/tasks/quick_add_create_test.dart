import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/parse/quick_add.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/core/tasks/quick_add_create.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // Wednesday 11 November 2026, 10:00.
  final now = DateTime.utc(2026, 11, 11, 10);
  const paris = 'Europe/Paris';

  late AppDatabase db;
  late LocalWriter writer;
  late String inbox;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    writer = LocalWriter(DriftLocalStore(db), deviceId: 'win-test');
    inbox = await writer.insert('lists', {'name': 'Inbox', 'is_inbox': true});
  });

  tearDown(() => db.close());

  Future<CreatedTask> create(String text) =>
      createQuickAddTask(writer, parseQuickAdd(text, now: now, zone: paris), fallbackListId: inbox);

  Future<Task> task(String id) => (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();

  test('a plain title makes a plain task in the fallback list', () async {
    final created = await create('Buy milk');
    final t = await task(created.id);
    expect(t.title, 'Buy milk');
    expect(t.listId, inbox);
    expect(t.dueAt, isNull);
    expect(t.priority, 0);
    expect(t.rrule, isNull);
    expect(t.tags, '');
    expect(t.status, 0);
    expect(created.missingList, isNull);
  });

  test('dates, priority, tags and list are all set on the task', () async {
    final work = await writer.insert('lists', {'name': 'Work'});
    final created = await create('Send the invoice tomorrow 3pm #finance #urgent ^Work !high');
    final t = await task(created.id);
    expect(t.title, 'Send the invoice');
    expect(t.listId, work);
    expect(t.priority, 5);
    expect(t.tags, 'finance,urgent');
    expect(t.dueAt, '2026-11-12T15:00:00+01:00');
    expect(t.tz, paris);
    expect(t.allDay, isFalse);
    expect(t.version, 1);
  });

  test('an all-day date is stored as a day with no zone', () async {
    final t = await task((await create('Pay rent friday')).id);
    expect(t.dueAt, '2026-11-13');
    expect(t.allDay, isTrue);
    expect(t.tz, isNull);
  });

  test('a repeat is stored as an rrule with its first due', () async {
    final t = await task((await create('Water the plants every monday')).id);
    expect(t.rrule, 'RRULE:FREQ=WEEKLY;BYDAY=MO');
    expect(t.dueAt, '2026-11-16');
    expect(t.repeatFrom, 'DUE');
  });

  test('the list is matched by name, ignoring case and spaces; archived and deleted lists do not count', () async {
    final home = await writer.insert('lists', {'name': 'Home Projects'});
    final old = await writer.insert('lists', {'name': 'Old', 'archived': true});
    final gone = await writer.insert('lists', {'name': 'Gone'});
    await writer.delete('lists', gone);
    expect((await task((await create('A ^"home projects"')).id)).listId, home);
    final archived = await create('B ^Old');
    expect((await task(archived.id)).listId, inbox);
    expect(archived.missingList, 'Old');
    expect((await create('C ^Gone')).missingList, 'Gone');
    expect(old, isNotEmpty);
  });

  test('a list that does not exist is not created: the task goes to the fallback list and the name comes back', () async {
    final created = await create('Call Sam ^Nowhere');
    expect((await task(created.id)).listId, inbox);
    expect(created.missingList, 'Nowhere');
    expect(await db.select(db.lists).get(), hasLength(1));
  });

  test('a new tag gets its row in the tags tab; a known one keeps its spelling and is not added twice', () async {
    await writer.insert('tags', {'name': 'Home', 'sort_order': 1.0});
    final t = await task((await create('Fix tap #home #plumbing')).id);
    expect(t.tags, 'Home,plumbing');
    final names = (await db.select(db.tags).get()).map((r) => r.name).toList()..sort();
    expect(names, ['Home', 'plumbing']);
  });

  test('everything is written in one transaction: a failure leaves no task and no tag', () async {
    final parsed = parseQuickAdd('Fix tap #plumbing', now: now, zone: paris);
    await writer.insert('tasks', {'id': 'taken', 'title': 'Already here'});
    // This writer hands out an id that a task already has, so inserting the new task fails.
    final broken = LocalWriter(DriftLocalStore(db), deviceId: 'win-test', newId: () => 'taken');
    await expectLater(createQuickAddTask(broken, parsed, fallbackListId: inbox), throwsStateError);
    expect((await db.select(db.tasks).get()).map((t) => t.title), ['Already here']);
    expect(await db.select(db.tags).get(), isEmpty);
  });
}
