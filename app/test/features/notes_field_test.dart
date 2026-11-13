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
import 'package:sheettick/features/tasks/notes_field.dart';

import '../support/fake_auth_service.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const markdown = '# Shopping\n\n- **milk**\n- bread\n\nSee [the shop](https://example.com/shop) or `code`.';

  Future<void> show(WidgetTester tester, TextEditingController c, {LinkOpener? open, Widget? below}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              TaskNotesField(controller: c, openLink: open ?? (_) async => true),
              below ?? const SizedBox(height: 200, child: Center(child: Text('elsewhere'))),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('empty notes show the field straight away', (tester) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await show(tester, c);
    expect(find.byKey(const Key('taskNotesField')), findsOneWidget);
    expect(find.byKey(const Key('taskNotesRendered')), findsNothing);
  });

  testWidgets('notes with text are shown rendered, not as raw Markdown', (tester) async {
    final c = TextEditingController(text: markdown);
    addTearDown(c.dispose);
    await show(tester, c);
    expect(find.byKey(const Key('taskNotesField')), findsNothing);
    expect(find.byKey(const Key('taskNotesRendered')), findsOneWidget);
    expect(find.text('Shopping'), findsOneWidget, reason: 'the heading, without its #');
    expect(find.textContaining('# Shopping'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(find.text('milk'), findsOneWidget);
    expect(find.text('bread'), findsOneWidget);
    expect(c.text, markdown, reason: 'the raw Markdown is untouched');
  });

  testWidgets('tapping the notes edits the raw text; tapping elsewhere renders it again', (tester) async {
    final c = TextEditingController(text: markdown);
    addTearDown(c.dispose);
    await show(tester, c);

    await tester.tap(find.byKey(const Key('taskNotesRendered')));
    await tester.pump();
    await tester.pump();
    final field = find.byKey(const Key('taskNotesField'));
    expect(field, findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, markdown);
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);

    await tester.enterText(field, '## Changed\n\n_new_ notes');
    await tester.tapAt(tester.getCenter(find.text('elsewhere')));
    await tester.pump();
    expect(find.byKey(const Key('taskNotesField')), findsNothing);
    expect(find.text('Changed'), findsOneWidget);
    expect(c.text, '## Changed\n\n_new_ notes');
  });

  testWidgets('clearing the notes leaves the field open instead of an empty rendering', (tester) async {
    final c = TextEditingController(text: 'x');
    addTearDown(c.dispose);
    await show(tester, c);
    await tester.tap(find.byKey(const Key('taskNotesRendered')));
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byKey(const Key('taskNotesField')), '');
    await tester.tapAt(tester.getCenter(find.text('elsewhere')));
    await tester.pump();
    expect(find.byKey(const Key('taskNotesField')), findsOneWidget);
  });

  group('links', () {
    testWidgets('a web link opens through the opener, and does not start editing', (tester) async {
      final c = TextEditingController(text: markdown);
      addTearDown(c.dispose);
      final opened = <Uri>[];
      await show(tester, c, open: (u) async {
        opened.add(u);
        return true;
      });
      await tester.tapOnText(find.textRange.ofSubstring('the shop'));
      await tester.pump();
      expect(opened.map((u) => u.toString()), ['https://example.com/shop']);
      expect(find.byKey(const Key('taskNotesField')), findsNothing);
    });

    testWidgets('a link that is not a web or mail address is not opened', (tester) async {
      final c = TextEditingController(text: 'Run [this](javascript:alert(1)) or [that](file:///etc/passwd)');
      addTearDown(c.dispose);
      final opened = <Uri>[];
      await show(tester, c, open: (u) async {
        opened.add(u);
        return true;
      });
      await tester.tapOnText(find.textRange.ofSubstring('this'));
      await tester.pump();
      expect(opened, isEmpty);
      expect(find.text('This link cannot be opened.'), findsOneWidget);
    });

    testWidgets('a link the system cannot open says so', (tester) async {
      final c = TextEditingController(text: '[a](https://example.com)');
      addTearDown(c.dispose);
      await show(tester, c, open: (_) async => false);
      await tester.tapOnText(find.textRange.ofSubstring('a'));
      await tester.pump();
      expect(find.text('Could not open the link.'), findsOneWidget);
    });

    testWidgets('an opener that throws does not crash the page', (tester) async {
      final c = TextEditingController(text: '[a](https://example.com)');
      addTearDown(c.dispose);
      await show(tester, c, open: (_) async => throw StateError('no browser'));
      await tester.tapOnText(find.textRange.ofSubstring('a'));
      await tester.pump();
      expect(find.text('Could not open the link.'), findsOneWidget);
    });
  });

  testWidgets('an image in a note is not fetched: its description shows instead', (tester) async {
    final c = TextEditingController(text: 'Before ![a cat](https://tracker.example/pixel.png) after');
    addTearDown(c.dispose);
    await show(tester, c);
    expect(find.byType(Image), findsNothing);
    expect(find.text('[image: a cat]'), findsOneWidget);
  });

  group('on the task page', () {
    late AppDatabase db;
    late DriftLocalStore store;
    LocalWriter writer() => LocalWriter(store, deviceId: 'win-test');

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftLocalStore(db);
    });

    tearDown(() => db.close());

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('the Sheet keeps the raw Markdown, whether or not the notes were edited', (tester) async {
      late String id;
      await tester.runAsync(() async {
        final inbox = await writer().insert('lists', {'name': 'Inbox', 'is_inbox': true});
        id = await writer().insert('tasks', {'list_id': inbox, 'title': 'Groceries', 'content': markdown});
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWith((ref) => 'win-test'),
          authServiceProvider.overrideWithValue(FakeAuthService()),
        ],
        child: const SheetTickApp(),
      ));
      await settle(tester);
      await tester.tap(find.text('Groceries'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);

      expect(find.byKey(const Key('taskNotesRendered')), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);

      // Leave the page without touching the notes: nothing is written.
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      final task = await tester.runAsync(() => (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle());
      expect(task!.content, markdown);
      expect(task.version, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
