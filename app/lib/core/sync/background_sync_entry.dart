import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:workmanager/workmanager.dart';

import '../auth/android_auth_service.dart';
import '../auth/oauth_config.dart';
import '../db/database.dart';
import '../reminders/platform_reminders.dart';
import '../reminders/replan.dart';
import '../sheets/google_sheets_backend.dart';
import 'background_sync.dart';

/// The WorkManager job that syncs while the app is closed (Android only, `docs/sync-protocol.md`).
const kBackgroundSyncUniqueName = 'sheettick-background-sync';
const kBackgroundSyncTaskName = 'sheettick.sync';

/// How often Android runs the job. 15 minutes is the shortest period WorkManager allows; the system may run it later to
/// save battery.
const kBackgroundSyncPeriod = Duration(minutes: 15);

/// Where WorkManager starts the job. It runs in its own isolate with no UI, so it opens the database itself, as the
/// notification handler does. Returning false asks WorkManager to try again later with backoff; a run that has nothing
/// to do (not signed in, spreadsheet not set up) reports success, so it is not retried over and over.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kBackgroundSyncTaskName) return true;
    DartPluginRegistrant.ensureInitialized();
    final db = AppDatabase.open();
    try {
      final auth = AndroidAuthService(config: const OAuthConfig());
      final outcome = await runBackgroundSync(
        db: db,
        openClient: () async => (await auth.restoreWithoutUi())?.client,
        backendFactory: GoogleSheetsBackend.new,
        deviceIdPrefix: 'and',
        replanReminders: () async {
          String? zone;
          try {
            zone = (await FlutterTimezone.getLocalTimezone()).identifier;
          } catch (_) {
            zone = null;
          }
          await replanReminders(db: db, scheduler: PlatformReminderScheduler(db), zone: zone, now: DateTime.now());
        },
      );
      debugPrint('Background sync: ${outcome.name}');
      return outcome != BackgroundSyncOutcome.retry;
    } catch (e) {
      debugPrint('Background sync crashed: $e');
      return false;
    } finally {
      await db.close();
    }
  });
}

/// Registers the periodic job (Android only; other platforms do nothing). Safe to call at every start: the job that is
/// already scheduled keeps its timing and only picks up changed settings. It needs a network connection, and retries a
/// failed run with exponential backoff.
Future<void> registerBackgroundSync() async {
  if (!Platform.isAndroid) return;
  try {
    await Workmanager().initialize(backgroundSyncDispatcher);
    await Workmanager().registerPeriodicTask(
      kBackgroundSyncUniqueName,
      kBackgroundSyncTaskName,
      frequency: kBackgroundSyncPeriod,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  } catch (e) {
    // Background sync is a convenience: the app still syncs while it is open.
    debugPrint('Could not schedule the background sync: $e');
  }
}
