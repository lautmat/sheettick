import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../auth/auth_service.dart' show AuthException;
import '../db/database.dart';
import '../time.dart';
import '../sheets/sheets_backend.dart';
import 'local_store.dart';
import 'sync_engine.dart';
import 'sync_errors.dart';

/// What one background run came to.
enum BackgroundSyncOutcome {
  /// A cycle ran.
  synced,

  /// Nothing to do: this device has never set up the spreadsheet (the first cycle is the app's, which can show
  /// errors), so the job waits for the app to be opened and signed in.
  notSetUp,

  /// Nothing to do: nobody is signed in, or Google would need the user to say yes again. The app asks when opened.
  signedOut,

  /// The spreadsheet itself needs the user (deleted, or a layout this version does not understand). Retrying would
  /// not help; the app says what is wrong when opened.
  blocked,

  /// The cycle failed (offline, a Google error, a busy database). Rows stay dirty, and the job should be tried again
  /// later with backoff.
  retry,
}

/// One background sync cycle for the periodic job (`docs/sync-protocol.md`): the same [SyncEngine] the app runs, with no
/// UI. It never asks the user for anything.
///
/// - [openClient] gives an authenticated client without any interaction, or null when that is not possible.
/// - [replanReminders] makes the reminders again from the database; it runs only when the cycle changed local rows
///   (step 6), and a failure in it does not undo the sync.
///
/// A failed cycle loses nothing: rows are marked synced only after the Sheet accepted them.
///
/// How the run went is recorded on the device ([DeviceStateKeys.lastBackgroundSync]) for the app to show.
Future<BackgroundSyncOutcome> runBackgroundSync({
  required AppDatabase db,
  required Future<http.Client?> Function() openClient,
  required SheetsBackend Function(http.Client client) backendFactory,
  required String deviceIdPrefix,
  required Future<void> Function() replanReminders,
  DateTime Function()? clock,
}) async {
  final outcome = await _run(
    db: db,
    openClient: openClient,
    backendFactory: backendFactory,
    deviceIdPrefix: deviceIdPrefix,
    replanReminders: replanReminders,
  );
  try {
    await db.setDeviceState(
      DeviceStateKeys.lastBackgroundSync,
      '${formatUtc((clock ?? DateTime.now)())}|${outcome.name}',
    );
  } catch (e) {
    debugPrint('Background sync could not record its outcome: $e');
  }
  return outcome;
}

Future<BackgroundSyncOutcome> _run({
  required AppDatabase db,
  required Future<http.Client?> Function() openClient,
  required SheetsBackend Function(http.Client client) backendFactory,
  required String deviceIdPrefix,
  required Future<void> Function() replanReminders,
}) async {
  final store = DriftLocalStore(db);
  if (await store.getState(DeviceStateKeys.spreadsheetId) == null) return BackgroundSyncOutcome.notSetUp;

  http.Client? client;
  try {
    client = await openClient();
  } on AuthException {
    return BackgroundSyncOutcome.signedOut;
  } catch (e) {
    debugPrint('Background sync could not open a Google client: $e');
    return BackgroundSyncOutcome.retry;
  }
  if (client == null) return BackgroundSyncOutcome.signedOut;

  try {
    final deviceId = await db.ensureDeviceId(deviceIdPrefix);
    final result = await SyncEngine(backend: backendFactory(client), store: store, deviceId: deviceId).sync();
    if (result.changedIds.values.any((ids) => ids.isNotEmpty)) {
      try {
        await replanReminders();
      } catch (e) {
        // The rows are saved; the app plans the reminders again the next time it is opened.
        debugPrint('Background sync could not plan reminders: $e');
      }
    }
    return BackgroundSyncOutcome.synced;
  } catch (e) {
    if (isAuthFailure(e)) return BackgroundSyncOutcome.signedOut;
    if (isBlockedBySpreadsheet(e)) return BackgroundSyncOutcome.blocked;
    debugPrint('Background sync failed: $e');
    return BackgroundSyncOutcome.retry;
  } finally {
    client.close();
  }
}

/// The line the app shows about the background sync, from the recorded [raw] value (`<UTC time>|<outcome name>`), or null
/// when it has not run. [now] is the current time.
String describeBackgroundSync(String? raw, DateTime now) {
  final parts = (raw ?? '').split('|');
  final at = parts.length == 2 ? DateTime.tryParse(parts[0]) : null;
  if (at == null) return 'Background sync: has not run yet';
  final outcome = BackgroundSyncOutcome.values.where((o) => o.name == parts[1]).firstOrNull;
  final what = switch (outcome) {
    BackgroundSyncOutcome.synced => 'synced',
    BackgroundSyncOutcome.notSetUp => 'waiting for the first sync in the app',
    BackgroundSyncOutcome.signedOut => 'skipped, Google needs you to sign in in the app',
    BackgroundSyncOutcome.blocked => 'stopped, the spreadsheet needs attention',
    BackgroundSyncOutcome.retry => 'failed, will try again',
    null => 'unknown result',
  };
  return 'Background sync: $what, ${_ago(now.difference(at.toUtc()))}';
}

String _ago(Duration d) {
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}
