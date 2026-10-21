import '../time.dart';
import '../sync/record.dart';

/// A task's `status` column (see `docs/sheet-schema.md`).
enum TaskStatus {
  open(0),
  completed(2),
  wontDo(-1);

  const TaskStatus(this.value);

  /// The value stored in the local row and in the Sheet.
  final int value;
}

/// The fields that set a task to [status] at [now]. Only completing stamps `completed_at`; reopening and won't do
/// clear it, so a task that is not done has no completion time.
Fields statusFields(TaskStatus status, DateTime now) => {
  'status': status.value,
  'completed_at': status == TaskStatus.completed ? formatUtc(now) : null,
};
