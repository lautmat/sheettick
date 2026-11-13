import 'dart:io' show SocketException;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sheettick/core/auth/auth_service.dart' show AuthException;
import 'package:sheettick/core/db/database.dart';
import 'package:sheettick/core/sheets/bootstrap.dart';
import 'package:sheettick/core/sync/background_sync.dart';

import '../../support/fake_sheets_backend.dart';
import '../../support/hooked_backend.dart';
import '../../support/test_device.dart';

class _Client extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => throw StateError('the fake backend never calls this');

  @override
  void close() => closed = true;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeSheetsBackend sheet;
  late HookedBackend hooked;
  late TestDevice pc;
  late TestDevice phone;
  late _Client client;
  var replans = 0;

  setUp(() async {
    sheet = FakeSheetsBackend();
    hooked = HookedBackend(sheet);
    pc = await TestDevice.create(sheet, id: 'win-0001');
    phone = await TestDevice.create(sheet, id: 'and-0001');
    client = _Client();
    replans = 0;
  });

  tearDown(() async {
    await pc.close();
    await phone.close();
  });

  Future<BackgroundSyncOutcome> run({
    AppDatabase? db,
    Future<_Client?> Function()? open,
    Future<void> Function()? replan,
  }) {
    return runBackgroundSync(
      db: db ?? phone.db,
      openClient: open ?? () async => client,
      backendFactory: (_) => hooked,
      deviceIdPrefix: 'and',
      replanReminders: replan ?? () async => replans++,
    );
  }

  test('a change made on the PC reaches the phone, and the reminders are planned again', () async {
    final id = await pc.addTask('Pay rent');
    await pc.sync();

    expect(await run(), BackgroundSyncOutcome.synced);

    final row = await phone.store.getRow('tasks', id);
    expect(row, isNotNull);
    expect(row!.fields['title'], 'Pay rent');
    expect(row.dirty, isFalse);
    expect(replans, 1);
    expect(client.closed, isTrue);
  });

  test('a run that changes no local row does not plan reminders', () async {
    await pc.addTask('Pay rent');
    await pc.sync();
    await run();
    expect(replans, 1);
    await run();
    expect(replans, 1);
  });

  test('what was edited on the phone while the app was closed is pushed, so the PC sees it', () async {
    final id = await phone.addTask('Buy milk');
    expect((await phone.task(id)).dirty, isTrue);

    expect(await run(), BackgroundSyncOutcome.synced);

    expect((await phone.task(id)).dirty, isFalse);
    await pc.sync();
    expect((await pc.task(id)).fields['title'], 'Buy milk');
  });

  test('a device that never set up the spreadsheet is skipped without asking for a client', () async {
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    var asked = false;
    final outcome = await run(db: fresh, open: () async {
      asked = true;
      return client;
    });
    expect(outcome, BackgroundSyncOutcome.notSetUp);
    expect(asked, isFalse);
  });

  group('signed out', () {
    test('no client: skipped, and local edits stay dirty for the app', () async {
      final id = await phone.addTask('Buy milk');
      expect(await run(open: () async => null), BackgroundSyncOutcome.signedOut);
      expect((await phone.task(id)).dirty, isTrue);
      expect(replans, 0);
    });

    test('the sign-in check says the user must act: skipped, not retried', () async {
      expect(await run(open: () async => throw AuthException('revoked')), BackgroundSyncOutcome.signedOut);
    });

    test('Google refuses the token during the cycle: skipped, not retried, client closed', () async {
      await phone.addTask('Buy milk');
      hooked.afterNextRead = () => throw AuthException('Google access was revoked or expired.');
      expect(await run(), BackgroundSyncOutcome.signedOut);
      expect(client.closed, isTrue);
    });
  });

  group('a failed cycle', () {
    test('offline: retry later, nothing is lost, and the next run delivers it', () async {
      final id = await phone.addTask('Buy milk');
      hooked.afterNextRead = () => throw const SocketException('no route to host');

      expect(await run(), BackgroundSyncOutcome.retry);
      expect((await phone.task(id)).dirty, isTrue, reason: 'rows are only marked synced once the Sheet has them');
      expect(client.closed, isTrue);

      expect(await run(), BackgroundSyncOutcome.synced);
      expect((await phone.task(id)).dirty, isFalse);
    });

    test('an unexpected error is retried too', () async {
      hooked.afterNextRead = () => throw StateError('boom');
      expect(await run(), BackgroundSyncOutcome.retry);
    });

    test('a client that cannot be opened is retried', () async {
      expect(await run(open: () async => throw StateError('plugin not ready')), BackgroundSyncOutcome.retry);
    });

    test('a spreadsheet problem the user must fix is not retried', () async {
      hooked.afterNextRead = () => throw SpreadsheetMissingException('gone');
      expect(await run(), BackgroundSyncOutcome.blocked);
      hooked.afterNextRead = () => throw SchemaTooNewException(9, 1);
      expect(await run(), BackgroundSyncOutcome.blocked);
    });
  });

  test('a failure while planning reminders does not undo the sync', () async {
    final id = await pc.addTask('Pay rent');
    await pc.sync();
    final outcome = await run(replan: () async => throw StateError('no alarm permission'));
    expect(outcome, BackgroundSyncOutcome.synced);
    expect(await phone.store.getRow('tasks', id), isNotNull);
  });

  test('it uses the device id the app already stored, and never makes a second one', () async {
    final appsId = await phone.db.ensureDeviceId('and');
    await run();
    await run();
    expect(await phone.db.getDeviceState(DeviceStateKeys.deviceId), appsId);
  });

  test('it makes one batched cycle, like the app: one read of the tabs', () async {
    sheet.calls.clear();
    await run();
    expect(sheet.calls['readRanges'], lessThanOrEqualTo(1));
  });

  group('what it records', () {
    test('every outcome is recorded with its time, for the app to show', () async {
      final at = DateTime.utc(2026, 11, 13, 7, 30, 15);
      Future<String?> recorded() => phone.db.getDeviceState(DeviceStateKeys.lastBackgroundSync);
      Future<BackgroundSyncOutcome> runAt() => runBackgroundSync(
        db: phone.db,
        openClient: () async => client,
        backendFactory: (_) => hooked,
        deviceIdPrefix: 'and',
        replanReminders: () async {},
        clock: () => at,
      );

      expect(await recorded(), isNull);
      await runAt();
      expect(await recorded(), '2026-11-13T07:30:15Z|synced');

      await phone.addTask('Buy milk');
      hooked.afterNextRead = () => throw const SocketException('offline');
      await runAt();
      expect(await recorded(), '2026-11-13T07:30:15Z|retry');
    });

    test('a skipped run is recorded too', () async {
      await run(open: () async => null);
      expect(await phone.db.getDeviceState(DeviceStateKeys.lastBackgroundSync), endsWith('|signedOut'));
    });
  });

  group('describeBackgroundSync', () {
    final now = DateTime.utc(2026, 11, 13, 8);

    test('says when it has not run', () {
      expect(describeBackgroundSync(null, now), 'Background sync: has not run yet');
      expect(describeBackgroundSync('', now), 'Background sync: has not run yet');
      expect(describeBackgroundSync('garbage', now), 'Background sync: has not run yet');
    });

    test('how long ago', () {
      String at(Duration ago) => describeBackgroundSync('${now.subtract(ago).toIso8601String()}|synced', now);
      expect(at(const Duration(seconds: 20)), 'Background sync: synced, just now');
      expect(at(const Duration(minutes: 12)), 'Background sync: synced, 12 min ago');
      expect(at(const Duration(hours: 5, minutes: 10)), 'Background sync: synced, 5 h ago');
      expect(at(const Duration(days: 3)), 'Background sync: synced, 3 d ago');
    });

    test('a time in the future, from clock skew or a bad value, reads as just now', () {
      String at(Duration ahead) => describeBackgroundSync('${now.add(ahead).toIso8601String()}|synced', now);
      expect(at(const Duration(seconds: 30)), 'Background sync: synced, just now');
      expect(at(const Duration(days: 2)), 'Background sync: synced, just now');
    });

    test('each outcome has plain words', () {
      String say(String outcome) => describeBackgroundSync('2026-11-13T07:50:00Z|$outcome', now);
      expect(say('signedOut'), contains('sign in in the app'));
      expect(say('notSetUp'), contains('first sync in the app'));
      expect(say('blocked'), contains('needs attention'));
      expect(say('retry'), contains('will try again'));
      expect(say('somethingNew'), contains('unknown result'));
    });
  });
}
