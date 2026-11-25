import '../db/database.dart';
import '../sync/local_writer.dart';
import '../tasks/task_completion.dart';
import '../tasks/task_status.dart';
import 'snooze.dart';

/// What the platform hands back when a notification's Done button is pressed.
const kDoneActionId = 'done';

/// Handles a press on a reminder notification's Done button: completes the reminder's task as the app does, so a
/// repeating task carries on to its next round ([setTaskStatus]), and returns its id. Returns null when [actionId] is not
/// Done, [payload] is not one of ours, or the task is gone, deleted or no longer open (finished on another device), in
/// which case nothing is written.
///
/// Garmin and other watches show an Android notification's buttons, so this is also how a task is ticked off from a
/// reminder on the wrist. [zone] is the IANA name of the device's zone, as for [setTaskStatus].
Future<String?> completeFromNotification({
  required String? actionId,
  required String? payload,
  required AppDatabase db,
  required LocalWriter writer,
  required DateTime now,
  required String? zone,
}) async {
  if (actionId != kDoneActionId) return null;
  final reminder = ReminderPayload.decode(payload);
  if (reminder == null) return null;
  final task = await (db.select(db.tasks)..where((t) => t.id.equals(reminder.taskId))).getSingleOrNull();
  if (task == null || task.deleted || task.status != TaskStatus.open.value) return null;
  await setTaskStatus(writer, task, TaskStatus.completed, now: now, zone: zone);
  return task.id;
}
