import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers.dart';
import '../sheets/bootstrap.dart';
import 'offline.dart';
import 'sync_engine.dart';

/// [offline] is not a failure: the device cannot reach Google right now, everything stays saved locally and the
/// next cycle (timer, resume, Sync now) tries again.
enum SyncPhase { idle, syncing, needsSignIn, offline, error }

class SyncStatus {
  const SyncStatus(this.phase, {this.lastSyncedAt, this.message});

  final SyncPhase phase;
  final DateTime? lastSyncedAt;

  /// A short explanation for [SyncPhase.error].
  final String? message;

  bool get isSyncing => phase == SyncPhase.syncing;
}

/// Runs sync cycles on the triggers of `docs/sync-protocol.md`: when asked (start, app resumed, "Sync now"),
/// [requestSoon] after a local edit (debounced), and every [period] while the app is open. The first cycle on a
/// device also bootstraps the spreadsheet.
class SyncController extends Notifier<SyncStatus> {
  static const debounce = Duration(seconds: 3);
  static const period = Duration(minutes: 2);

  Timer? _debounceTimer;

  @override
  SyncStatus build() {
    final periodic = Timer.periodic(period, (_) => sync());
    ref.onDispose(() {
      periodic.cancel();
      _debounceTimer?.cancel();
    });
    return const SyncStatus(SyncPhase.idle);
  }

  /// Schedules a cycle shortly after the last local edit.
  void requestSoon() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, sync);
  }

  Future<void> sync() async {
    if (state.isSyncing) return;
    final backend = ref.read(sheetsBackendProvider);
    if (backend == null) {
      state = SyncStatus(SyncPhase.needsSignIn, lastSyncedAt: state.lastSyncedAt);
      return;
    }
    state = SyncStatus(SyncPhase.syncing, lastSyncedAt: state.lastSyncedAt);
    try {
      final db = ref.read(appDatabaseProvider);
      final store = ref.read(localStoreProvider);
      final deviceId = await ref.read(deviceIdProvider.future);
      if (await store.getState(DeviceStateKeys.spreadsheetId) == null) {
        await SheetBootstrap(backend: backend, db: db, deviceId: deviceId, appVersion: kAppVersion).run();
      }
      await SyncEngine(backend: backend, store: store, deviceId: deviceId).sync();
      state = SyncStatus(SyncPhase.idle, lastSyncedAt: DateTime.now());
    } catch (e) {
      state = isOfflineError(e)
          ? SyncStatus(SyncPhase.offline, lastSyncedAt: state.lastSyncedAt)
          : SyncStatus(SyncPhase.error, lastSyncedAt: state.lastSyncedAt, message: _describe(e));
    }
  }

  String _describe(Object e) => switch (e) {
    SpreadsheetMissingException() => 'The SheetTick spreadsheet was deleted or trashed in Google Drive.',
    SchemaTooNewException() => 'The spreadsheet was written by a newer version of SheetTick. Update the app.',
    SchemaMismatchException() => 'A header row in the spreadsheet was changed by hand: $e',
    _ => '$e',
  };
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(SyncController.new);
