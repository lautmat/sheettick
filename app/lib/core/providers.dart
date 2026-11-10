import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;

import 'auth/auth_controller.dart';
import 'db/database.dart';
import 'reminders/reminder_scheduler.dart';
import 'sheets/google_sheets_backend.dart';
import 'sheets/sheets_backend.dart';
import 'sync/local_store.dart';
import 'sync/local_writer.dart';

/// Version written to `meta.created_by_app_version` (keep in step with `pubspec.yaml`).
const kAppVersion = '0.1.0';

/// The on-device SQLite database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

/// This install's short id: `win-xxxx` on Windows, `and-xxxx` on Android.
final deviceIdProvider = FutureProvider<String>((ref) {
  final prefix = Platform.isWindows ? 'win' : (Platform.isAndroid ? 'and' : 'dev');
  return ref.watch(appDatabaseProvider).ensureDeviceId(prefix);
});

/// The IANA name of the device's time zone (`Europe/Paris`), or null when the platform cannot say. Dates then fall back
/// to the platform's own zone, with no name. Tests override this.
final deviceZoneProvider = FutureProvider<String?>((ref) async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } on MissingPluginException {
    // No platform side, as in a unit test: the platform's own zone is used.
    return null;
  } catch (e) {
    debugPrint('Could not read the device time zone: $e');
    return null;
  }
});

/// Delivers reminders (see `core/reminders`). Shows nothing until `main` overrides it with the platform's notifications,
/// which keeps tests off the platform plugin.
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) => const NoopReminderScheduler());

final localStoreProvider =Provider<LocalStore>((ref) => DriftLocalStore(ref.watch(appDatabaseProvider)));

/// How the UI changes rows (see [LocalWriter]).
final localWriterProvider = FutureProvider<LocalWriter>((ref) async {
  final deviceId = await ref.watch(deviceIdProvider.future);
  return LocalWriter(ref.watch(localStoreProvider), deviceId: deviceId);
});

/// Builds the Drive + Sheets backend for a signed-in client. Tests override this with a fake.
final backendFactoryProvider = Provider<SheetsBackend Function(http.Client)>((ref) => GoogleSheetsBackend.new);

/// The Drive + Sheets client, or null while the user is not signed in.
final sheetsBackendProvider = Provider<SheetsBackend?>((ref) {
  final session = ref.watch(authControllerProvider.select((s) => s.session));
  if (session == null) return null;
  return ref.watch(backendFactoryProvider)(session.client);
});
