import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';

/// Whether the account menu shows how the background sync went: only where there is one (Android). Tests override it.
final backgroundSyncVisibleProvider = Provider<bool>((ref) => Platform.isAndroid);

/// The recorded outcome of the last background sync (see `describeBackgroundSync`), read fresh each time the menu opens
/// because the background job writes it from another isolate.
final backgroundSyncRecordProvider = FutureProvider.autoDispose<String?>(
  (ref) => ref.watch(appDatabaseProvider).getDeviceState(DeviceStateKeys.lastBackgroundSync),
);
