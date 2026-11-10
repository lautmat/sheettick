import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tzdb;

import '../db/database.dart';
import '../time.dart';
import 'alarm_reminder_scheduler.dart';
import 'reminder_planner.dart';
import 'reminder_scheduler.dart';

const _androidChannelId = 'reminders';

/// The platform's notifications through `flutter_local_notifications`: alarms on Android, a running check on Windows
/// (see [PollingReminderScheduler] for why). Set up on first use. If the platform cannot do it, reminders are simply
/// not shown and nothing else is affected.
class PlatformReminderScheduler implements ReminderScheduler {
  PlatformReminderScheduler(this._db);

  final AppDatabase _db;
  Future<ReminderScheduler>? _inner;

  Future<ReminderScheduler> _delegate() => _inner ??= _create();

  Future<ReminderScheduler> _create() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      if (Platform.isAndroid) {
        await plugin.initialize(
          settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        );
        return AlarmReminderScheduler(_PluginAlarmPort(plugin));
      }
      if (Platform.isWindows) {
        await plugin.initialize(
          settings: const InitializationSettings(
            windows: WindowsInitializationSettings(
              appName: 'SheetTick',
              appUserModelId: 'com.lmathieu.sheettick',
              guid: 'b3f1c7a2-5d84-4e6b-9a0c-7e2d4f8a1c35',
            ),
          ),
        );
        return PollingReminderScheduler(
          show: (r) => plugin.show(
            id: r.notificationId,
            title: r.title,
            body: r.body,
            notificationDetails: const NotificationDetails(windows: WindowsNotificationDetails()),
            payload: r.taskId,
          ),
          clock: DateTime.now,
          loadLastLook: () async {
            final saved = await _db.getDeviceState(DeviceStateKeys.lastReminderLook);
            return saved == null ? null : DateTime.tryParse(saved);
          },
          saveLastLook: (time) => _db.setDeviceState(DeviceStateKeys.lastReminderLook, formatUtc(time)),
        );
      }
    } catch (e) {
      debugPrint('Notifications are not available: $e');
    }
    return const NoopReminderScheduler();
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
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          'Reminders',
          channelDescription: 'Reminders for tasks with a start or due date',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
