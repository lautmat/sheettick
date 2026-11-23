import '../db/database.dart';
import 'reminder_planner.dart';
import 'reminder_scheduler.dart';
import 'snooze.dart';

/// How far back a reminder still counts when the app was closed or asleep, and how far ahead it is planned.
const kReminderLookBack = Duration(hours: 24);
const kReminderLookAhead = Duration(days: 90);

/// Plans the reminders of every task in [db] (with the snoozes recorded there) and hands the plan to [scheduler], which
/// replaces what it had. For callers with no running UI to watch the tasks, such as the background sync
/// (`docs/sync-protocol.md`, step 6). [zone] is the IANA name of the device's zone, or null when it is not known.
Future<void> replanReminders({
  required AppDatabase db,
  required ReminderScheduler scheduler,
  required String? zone,
  required DateTime now,
}) async {
  final tasks = await db.select(db.tasks).get();
  final snoozes = await snoozeStoreOf(db).load();
  final plan = planReminders(
    tasks,
    after: now.subtract(kReminderLookBack),
    until: now.add(kReminderLookAhead),
    deviceZone: zone,
    snoozes: snoozes,
  );
  await scheduler.replaceAll(plan, now);
}
