import '../sync/record.dart';
import '../time.dart';

/// The `kind` of a task that holds a checklist.
const kChecklistKind = 'CHECKLIST';

/// The fields that tick (or untick) a checklist item at [now]. An item's `status` is `2` when done, `0` when open,
/// as for a task. Ticking stamps `completed_at`; unticking clears it.
Fields checklistItemFields({required bool done, required DateTime now}) => {
  'status': done ? 2 : 0,
  'completed_at': done ? formatUtc(now) : null,
};

/// [items] after the item at [oldIndex] is moved to [newIndex], the position it ends up at, as `ReorderableListView`
/// reports a move through `onReorderItem`.
List<T> checklistOrderAfterMove<T>(List<T> items, int oldIndex, int newIndex) {
  final moved = [...items];
  moved.insert(newIndex, moved.removeAt(oldIndex));
  return moved;
}
