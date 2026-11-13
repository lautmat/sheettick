import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/providers.dart';
import 'package:sheettick/core/sync/local_store.dart';
import 'package:sheettick/core/sync/local_writer.dart';
import 'package:sheettick/features/import/import_dialog.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('dry run shows the plan and writes nothing; Import writes once', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final store = DriftLocalStore(db);
    addTearDown(() => tester.runAsync(db.close));
    await tester.runAsync(() => LocalWriter(store, deviceId: 'win-test').insert('lists', {'name': 'Inbox', 'is_inbox': true}));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWith((ref) => 'win-test'),
      ],
      child: const MaterialApp(home: Scaffold(body: TickTickImportDialog())),
    ));

    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
    }

    Future<int> taskCount() async => (await tester.runAsync(() => store.rowsById('tasks')))!.length;

    expect(tester.widget<FilledButton>(find.byKey(const Key('importGo'))).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('importJson')), jsonEncode([{'id': 'a', 'title': 'Buy milk', 'status': 0}]));
    await tester.tap(find.byKey(const Key('importDryRun')));
    await settle();
    expect(find.textContaining('Would write 1 tasks'), findsOneWidget);
    expect(await taskCount(), 0);

    await tester.tap(find.byKey(const Key('importGo')));
    await settle();
    expect(find.textContaining('1 written'), findsOneWidget);
    expect(await taskCount(), 1);

    // Editing the text goes back to the dry-run step.
    await tester.enterText(find.byKey(const Key('importJson')), '[]');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('importGo'))).onPressed, isNull);
  });

  testWidgets('a bad paste says so', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final store = DriftLocalStore(db);
    addTearDown(() => tester.runAsync(db.close));
    await tester.runAsync(() => LocalWriter(store, deviceId: 'win-test').insert('lists', {'name': 'Inbox', 'is_inbox': true}));
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db), deviceIdProvider.overrideWith((ref) => 'win-test')],
      child: const MaterialApp(home: Scaffold(body: TickTickImportDialog())),
    ));
    await tester.enterText(find.byKey(const Key('importJson')), 'not json');
    await tester.tap(find.byKey(const Key('importDryRun')));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(find.textContaining('Cannot read this'), findsOneWidget);
  });
}
