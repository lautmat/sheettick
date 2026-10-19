import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late DriftLocalStore store;
  late LocalWriter writer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
    writer = LocalWriter(store, deviceId: 'win-0001');
  });
  tearDown(() => db.close());

  group('table names', () {
    test('an unknown table is a clear error, from every entry point', () async {
      await expectLater(store.getRow('nope', 'x'), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('not a table'))));
      await expectLater(store.rowsById('nope'), throwsArgumentError);
      await expectLater(store.clearSheetRows('nope'), throwsArgumentError);
      await expectLater(store.setSheetRow('nope', 'x', 1), throwsArgumentError);
    });

    test('a name carrying SQL is rejected before it can reach a query', () async {
      await expectLater(store.normalize('tasks; DROP TABLE tasks', {}), throwsArgumentError);
      await expectLater(store.dirtyCount(['tasks WHERE 1=1; --']), throwsArgumentError);
      // The database is untouched.
      expect(await store.rowsById('tasks'), isEmpty);
    });
  });

  group('LocalWriter.insert', () {
    test('refuses an id that already exists instead of overwriting the row', () async {
      await writer.insert('tasks', {'id': 'fixed-id', 'title': 'original'});
      await expectLater(
        writer.insert('tasks', {'id': 'fixed-id', 'title': 'impostor'}),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('already exists'))),
      );
      expect((await store.getRow('tasks', 'fixed-id'))!.fields['title'], 'original');
    });

    test('generates distinct ids when none is given', () async {
      final a = await writer.insert('tasks', {'title': 'a'});
      final b = await writer.insert('tasks', {'title': 'b'});
      expect(a, isNot(b));
      expect((await store.rowsById('tasks')).length, 2);
    });
  });
}
