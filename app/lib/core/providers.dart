import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'auth/auth_controller.dart';
import 'db/database.dart';
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

final localStoreProvider = Provider<LocalStore>((ref) => DriftLocalStore(ref.watch(appDatabaseProvider)));

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
