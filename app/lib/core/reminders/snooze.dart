import 'dart:convert';

import '../db/database.dart';
import 'reminder_planner.dart';

/// A reminder moved to a later time on this device. [from] is the instant the reminder was due; the snooze belongs to
/// that occurrence only, so when the task's date moves the snooze no longer applies.
class Snooze {
  const Snooze({required this.from, required this.until});

  final DateTime from;
  final DateTime until;

  @override
  bool operator ==(Object other) => other is Snooze && other.from == from && other.until == until;

  @override
  int get hashCode => Object.hash(from, until);
}

/// The snoozed reminders of this device, by reminder key (see [PlannedReminder.key]).
///
/// Each snooze is its own stored value, so two writers (the app and the background handler of a notification button,
/// which have separate database connections) never overwrite each other: setting one is a single upsert, and nothing
/// reads the others first.
///
/// A snooze is not synced: it is "remind me again here, soon", and the task's dates and `reminders` are not touched.
/// Another device still reminds at the original time.
class SnoozeStore {
  SnoozeStore({required this.readAll, required this.write, required this.remove});

  /// Every stored snooze: reminder key to the stored text.
  final Future<Map<String, String>> Function() readAll;
  final Future<void> Function(String key, String value) write;
  final Future<void> Function(Iterable<String> keys) remove;

  /// A snooze that ended more than this long ago is forgotten.
  static const keepAfterEnd = Duration(days: 1);

  Future<Map<String, Snooze>> load() async {
    final result = <String, Snooze>{};
    (await readAll()).forEach((key, text) {
      final snooze = _decode(text);
      if (snooze != null) result[key] = snooze;
    });
    return result;
  }

  static Snooze? _decode(String text) {
    try {
      final m = jsonDecode(text);
      if (m is! Map) return null;
      final from = m['from'], until = m['until'];
      if (from is! int || until is! int) return null;
      return Snooze(
        from: DateTime.fromMillisecondsSinceEpoch(from, isUtc: true),
        until: DateTime.fromMillisecondsSinceEpoch(until, isUtc: true),
      );
    } on FormatException {
      return null;
    }
  }

  /// Moves the reminder [key], due at [from], to [until]. Snoozing it again replaces the earlier snooze. Snoozes that
  /// ended long ago are removed.
  Future<void> snooze(String key, {required DateTime from, required DateTime until, required DateTime now}) async {
    await write(
      key,
      jsonEncode({'from': from.toUtc().millisecondsSinceEpoch, 'until': until.toUtc().millisecondsSinceEpoch}),
    );
    final cutoff = now.subtract(keepAfterEnd);
    final old = [
      for (final e in (await load()).entries)
        if (e.key != key && e.value.until.isBefore(cutoff)) e.key,
    ];
    if (old.isNotEmpty) await remove(old);
  }
}

/// The snooze store kept in [db]'s `device_state` table, one row per snoozed reminder.
SnoozeStore snoozeStoreOf(AppDatabase db) => SnoozeStore(
  readAll: () => db.deviceStateWithPrefix(DeviceStateKeys.reminderSnoozePrefix),
  write: (key, value) => db.setDeviceState('${DeviceStateKeys.reminderSnoozePrefix}$key', value),
  remove: (keys) => db.deleteDeviceState([for (final k in keys) '${DeviceStateKeys.reminderSnoozePrefix}$k']),
);

/// What a notification carries back to the app when it is tapped or one of its buttons is: enough to snooze it with the
/// app closed, without reading a task.
class ReminderPayload {
  const ReminderPayload({
    required this.taskId,
    required this.key,
    required this.originalAt,
    required this.title,
    required this.body,
  });

  factory ReminderPayload.of(PlannedReminder r) =>
      ReminderPayload(taskId: r.taskId, key: r.key, originalAt: r.originalAt, title: r.title, body: r.body);

  final String taskId;
  final String key;
  final DateTime originalAt;
  final String title;
  final String body;

  String encode() => jsonEncode({
    't': taskId,
    'k': key,
    'o': originalAt.millisecondsSinceEpoch,
    'ti': title,
    'b': body,
  });

  /// Null for a payload this version did not write (an older notification carried just the task id).
  static ReminderPayload? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final m = jsonDecode(text);
      if (m is! Map) return null;
      final t = m['t'], k = m['k'], o = m['o'], ti = m['ti'], b = m['b'];
      if (t is! String || k is! String || o is! int || ti is! String || b is! String) return null;
      return ReminderPayload(
        taskId: t,
        key: k,
        originalAt: DateTime.fromMillisecondsSinceEpoch(o, isUtc: true),
        title: ti,
        body: b,
      );
    } on FormatException {
      return null;
    }
  }
}

/// A snooze button on a notification.
enum SnoozeAction {
  tenMinutes('snooze:10m', '10 min', Duration(minutes: 10)),
  oneHour('snooze:1h', '1 hour', Duration(hours: 1));

  const SnoozeAction(this.id, this.label, this.length);

  /// What the platform hands back when the button is pressed.
  final String id;
  final String label;
  final Duration length;

  static SnoozeAction? byId(String? id) {
    for (final a in values) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// Handles a press on a notification's snooze button: records the snooze and returns it, or null when [actionId] is not
/// a snooze button or [payload] is not one of ours. The caller then makes the platform notify at [Snooze.until].
Future<({ReminderPayload reminder, Snooze snooze})?> snoozeFromNotification({
  required String? actionId,
  required String? payload,
  required DateTime now,
  required SnoozeStore store,
}) async {
  final action = SnoozeAction.byId(actionId);
  final reminder = ReminderPayload.decode(payload);
  if (action == null || reminder == null) return null;
  final until = now.add(action.length);
  await store.snooze(reminder.key, from: reminder.originalAt, until: until, now: now);
  return (reminder: reminder, snooze: Snooze(from: reminder.originalAt, until: until.toUtc()));
}
