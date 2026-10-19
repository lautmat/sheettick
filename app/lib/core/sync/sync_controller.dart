import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/drive/v3.dart' show DetailedApiRequestError;
import 'package:googleapis_auth/googleapis_auth.dart' show AccessDeniedException;

import '../auth/auth_controller.dart';
import '../auth/auth_service.dart' show AuthException;
import '../db/database.dart';
import '../providers.dart';
import '../sheets/bootstrap.dart';
import 'sync_engine.dart';

enum SyncPhase { idle, syncing, needsSignIn, error }

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
    // Signing in (or restoring a session at startup) is a sync trigger.
    ref.listen(sheetsBackendProvider, (previous, next) {
      if (next != null) sync();
    });
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
      if (_isAuthFailure(e)) {
        const message = 'Google no longer accepts this sign-in. Please sign in again.';
        ref.read(authControllerProvider.notifier).sessionExpired(message);
        state = SyncStatus(SyncPhase.needsSignIn, lastSyncedAt: state.lastSyncedAt);
      } else {
        state = SyncStatus(SyncPhase.error, lastSyncedAt: state.lastSyncedAt, message: _describe(e));
      }
    }
  }

  /// The refresh token was revoked or the access was withdrawn (as opposed to a network or server problem).
  /// A 403 is deliberately not included: Google also uses it for rate limits and for an API that is not enabled
  /// in the Cloud project, and signing the user out would not fix either.
  bool _isAuthFailure(Object e) =>
      e is AccessDeniedException || e is AuthException || (e is DetailedApiRequestError && e.status == 401);

  String _describe(Object e) => switch (e) {
    SpreadsheetMissingException() => 'The SheetTick spreadsheet was deleted or trashed in Google Drive.',
    SchemaTooNewException() => 'The spreadsheet was written by a newer version of SheetTick. Update the app.',
    SchemaMismatchException() => 'A header row in the spreadsheet was changed by hand: $e',
    _ => '$e',
  };
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(SyncController.new);
