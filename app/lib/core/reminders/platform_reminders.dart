import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart' show VoidCallback, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tzdb;

import '../db/database.dart';
import '../time.dart';
import 'alarm_reminder_scheduler.dart';
import 'reminder_planner.dart';
import 'reminder_scheduler.dart';
import 'snooze.dart';
import 'windows_notification_setting.dart';

const _androidChannelId = 'reminders';
const _windowsAppId = 'com.lmathieu.sheettick';

const _androidSettings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));

/// The platform's notifications through `flutter_local_notifications`: alarms on Android, a running check on Windows
/// (see [PollingReminderScheduler] for why). Set up on first use. If the platform cannot do it, reminders are simply
/// not shown and nothing else is affected.
///
/// Pressing a snooze button on a notification records the snooze and calls [onSnoozed], so the plan is made again.
class PlatformReminderScheduler implements ReminderScheduler {
  PlatformReminderScheduler(this._db, {this.onSnoozed});

  final AppDatabase _db;
  final VoidCallback? onSnoozed;
  Future<ReminderScheduler>? _inner;

  Future<ReminderScheduler> _delegate() => _inner ??= _create();

  Future<ReminderScheduler> _create() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      if (Platform.isAndroid) {
        await plugin.initialize(
          settings: _androidSettings,
          onDidReceiveNotificationResponse: _onResponse,
          // With the app closed, a snooze button runs this in a background isolate.
          onDidReceiveBackgroundNotificationResponse: reminderBackgroundResponse,
        );
        return AlarmReminderScheduler(_PluginAlarmPort(plugin));
      }
      if (Platform.isWindows) {
        await plugin.initialize(
          settings: const InitializationSettings(
            windows: WindowsInitializationSettings(
              appName: 'SheetTick',
              appUserModelId: _windowsAppId,
              guid: 'b3f1c7a2-5d84-4e6b-9a0c-7e2d4f8a1c35',
            ),
          ),
          onDidReceiveNotificationResponse: _onResponse,
        );
        return PollingReminderScheduler(
          show: (r) => plugin.show(
            id: r.notificationId,
            title: r.title,
            body: r.body,
            notificationDetails: NotificationDetails(
              windows: WindowsNotificationDetails(
                actions: [
                  for (final a in SnoozeAction.values) WindowsAction(content: 'Snooze ${a.label}', arguments: a.id),
                ],
              ),
            ),
            payload: ReminderPayload.of(r).encode(),
          ),
          clock: DateTime.now,
          loadLastLook: () async {
            final saved = await _db.getDeviceState(DeviceStateKeys.lastReminderLook);
            return saved == null ? null : DateTime.tryParse(saved);
          },
          saveLastLook: (time) => _db.setDeviceState(DeviceStateKeys.lastReminderLook, formatUtc(time)),
          notificationsEnabled: WindowsNotificationSetting(appId: _windowsAppId).areEnabled,
        );
      }
    } catch (e) {
      debugPrint('Notifications are not available: $e');
    }
    return const NoopReminderScheduler();
  }

  /// A press on a notification or one of its buttons while the app runs.
  void _onResponse(NotificationResponse response) {
    unawaited(() async {
      try {
        final done = await snoozeFromNotification(
          actionId: response.actionId,
          payload: response.payload,
          now: DateTime.now(),
          store: snoozeStoreOf(_db),
        );
        if (done != null) onSnoozed?.call();
      } catch (e) {
        debugPrint('Could not snooze the reminder: $e');
      }
    }());
  }

  @override
  void dispose() {
    final inner = _inner;
    if (inner != null) unawaited(inner.then((s) => s.dispose(), onError: (Object _) {}));
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await (await _delegate()).requestPermission();
    } catch (e) {
      debugPrint('Could not ask for notification permission: $e');
      return false;
    }
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> plan, DateTime now) async {
    try {
      await (await _delegate()).replaceAll(plan, now);
    } catch (e) {
      // A failure here must never reach the tasks: the rows are untouched and the next plan tries again.
      debugPrint('Could not schedule reminders: $e');
    }
  }
}

/// A press on a notification button on Android, with the app closed. It runs in its own isolate, so it opens the
/// database itself, records the snooze, and sets the alarm for the new time directly: the running app, if there is one,
/// reads the snooze from the database the next time it plans.
@pragma('vm:entry-point')
Future<void> reminderBackgroundResponse(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  final db = AppDatabase.open();
  try {
    final done = await snoozeFromNotification(
      actionId: response.actionId,
      payload: response.payload,
      now: DateTime.now(),
      store: snoozeStoreOf(db),
    );
    if (done == null) return;
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(settings: _androidSettings);
    final port = _PluginAlarmPort(plugin);
    await port.schedule(
      id: notificationIdOf(done.reminder.key),
      at: done.snooze.until,
      title: done.reminder.title,
      body: done.reminder.body,
      payload: done.reminder.encode(),
      exact: await port.canScheduleExact(),
    );
  } catch (e) {
    debugPrint('Could not snooze the reminder: $e');
  } finally {
    await db.close();
  }
}

class _PluginAlarmPort implements AlarmPort {
  _PluginAlarmPort(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> requestPermission() async {
    final android = _android;
    if (android == null) return false;
    final allowed = await android.requestNotificationsPermission() ?? false;
    // Android 12 asks for exact alarms in settings; later versions grant them with the app.
    if (allowed && !(await android.canScheduleExactNotifications() ?? false)) {
      await android.requestExactAlarmsPermission();
    }
    return allowed;
  }

  @override
  Future<bool> canScheduleExact() async => await _android?.canScheduleExactNotifications() ?? false;

  @override
  Future<Set<int>> pendingIds() async => {for (final p in await _plugin.pendingNotificationRequests()) p.id};

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    required bool exact,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: payload,
      scheduledDate: tzdb.TZDateTime.fromMillisecondsSinceEpoch(tzdb.UTC, at.millisecondsSinceEpoch),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          'Reminders',
          channelDescription: 'Reminders for tasks with a start or due date',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          actions: [for (final a in SnoozeAction.values) AndroidNotificationAction(a.id, 'Snooze ${a.label}')],
        ),
      ),
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
