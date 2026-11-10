import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/app.dart';
import 'package:sheettick/core/auth/auth_controller.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/providers.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';

import '../support/fake_auth_service.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftLocalStore store;
  LocalWriter writer() => LocalWriter(store, deviceId: 'win-test');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  Widget app() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWith((ref) => 'win-test'),
        deviceZoneProvider.overrideWith((ref) async => 'Europe/Paris'),
        authServiceProvider.overrideWithValue(FakeAuthService()),
      ],
      child: const SheetTickApp(),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<Map<String, String>> seed(WidgetTester tester) async {
    final ids = <String, String>{};
    await tester.runAsync(() async {
      final w = writer();
      final inbox = await w.insert('lists', {'name': 'Inbox', 'is_inbox': true});
      final work = await w.insert('lists', {'name': 'Work'});
      Future<void> task(String title, {String content = '', String? list, bool trash = false, int status = 0}) async {
        final id = await w.insert('tasks', {
          'title': title,
          'content': content,
          'list_id': list ?? inbox,
          'status': status,
        });
        if (trash) await w.delete('tasks', id);
        ids[title] = id;
      }

      await task('Buy milk');
      await task('Call the plumber', content: 'About the kitchen tap, ask for a quote');
      await task('Quarterly report', list: work, content: 'Milk run for the office too');
      await task('Milk the cows', trash: true);
      await task('Old milk order', status: 2);
    });
    return ids;
  }

  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('searchButton')));
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('searchField')), text);
    await settle(tester);
  }

  Set<String> shown(Iterable<String> titles) => {
    for (final t in titles)
      if (find.descendant(of: find.byType(ListTile), matching: find.text(t)).evaluate().isNotEmpty) t,
  };

  const all = ['Buy milk', 'Call the plumber', 'Quarterly report', 'Milk the cows', 'Old milk order'];

  testWidgets('results follow what is typed, and match the notes as well as the title', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seed(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    await openSearch(tester);
    expect(find.textContaining('Type to search'), findsOneWidget);

    await type(tester, 'mi');
    // Prefix match on every word: both titles with "milk" and the note "Milk run". The trashed task is left out.
    expect(shown(all), {'Buy milk', 'Quarterly report', 'Old milk order'});

    await type(tester, 'milk run');
    expect(shown(all), {'Quarterly report'});

    await type(tester, 'plumber');
    expect(shown(all), {'Call the plumber'});

    await type(tester, 'quote');
    expect(shown(all), {'Call the plumber'});
    await unmount(tester);
  });

  testWidgets('each result shows its list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ids = await seed(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    await openSearch(tester);

    await type(tester, 'milk');
    expect(tester.widget<Text>(find.byKey(Key('resultList-${ids['Buy milk']}'))).data, 'Inbox');
    expect(tester.widget<Text>(find.byKey(Key('resultList-${ids['Quarterly report']}'))).data, 'Work');
    await unmount(tester);
  });

  testWidgets('deleted tasks are never found, and a search with no match says so', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seed(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    await openSearch(tester);

    await type(tester, 'cows');
    expect(find.byKey(const Key('searchEmpty')), findsOneWidget);
    expect(find.text('Milk the cows'), findsNothing);
    await unmount(tester);
  });

  testWidgets('punctuation and operators typed by the user do not break the search', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seed(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    await openSearch(tester);

    for (final q in ['"', 'milk OR', '(', 'title:milk', '--']) {
      await type(tester, q);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Could not search'), findsNothing);
    }
    await unmount(tester);
  });

  testWidgets('a task changed while the search is open is searched again', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ids = await seed(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    await openSearch(tester);
    await type(tester, 'milk');
    expect(shown(all), contains('Buy milk'));

    await tester.runAsync(() => writer().update('tasks', ids['Buy milk']!, {'title': 'Buy bread'}));
    await settle(tester);
    expect(shown(all), isNot(contains('Buy milk')));
    await unmount(tester);
  });

  testWidgets('clearing the field goes back to the prompt, and a result opens the task', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ids = await seed(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    await openSearch(tester);

    await type(tester, 'plumber');
    await tester.tap(find.byKey(Key('result-${ids['Call the plumber']}')));
    await settle(tester);
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Call the plumber'), findsWidgets);
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.byKey(const Key('clearSearch')));
    await settle(tester);
    expect(find.textContaining('Type to search'), findsOneWidget);
    await unmount(tester);
  });
}
