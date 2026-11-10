import '../parse/quick_add.dart';
import '../sync/local_writer.dart';
import 'tags.dart';

/// A task made from quick-add text.
class CreatedTask {
  const CreatedTask({required this.id, this.missingList});

  final String id;

  /// The list the text named with `^` when no live list has that name; the task went to the fallback list instead.
  final String? missingList;
}

/// Creates the task [parsed] describes, in one transaction.
///
/// It goes to the list the text named with `^` (matched by name, ignoring case; archived and deleted lists do not
/// count), else to [fallbackListId]. A name that matches no list does not create one: the task goes to the fallback list
/// and the name is returned as [CreatedTask.missingList] so the caller can say so. Tags are added the way the task page
/// adds them (see [ensureTag]), so a new tag also gets its row in the `tags` tab. The task is written once, with its
/// tags, so it starts at version 1.
Future<CreatedTask> createQuickAddTask(
  LocalWriter writer,
  QuickAddResult parsed, {
  required String fallbackListId,
}) {
  return writer.store.transaction(() async {
    var listId = fallbackListId;
    String? missing;
    final name = parsed.listName?.trim();
    if (name != null && name.isNotEmpty) {
      final lists = (await writer.store.rowsById('lists')).values
          .map((r) => r.fields)
          .where((f) => f['deleted'] != true && f['archived'] != true);
      final hit = lists.where((f) => ((f['name'] as String?) ?? '').trim().toLowerCase() == name.toLowerCase()).firstOrNull;
      if (hit != null) {
        listId = hit['id'] as String;
      } else {
        missing = name;
      }
    }
    var tags = <String>[];
    for (final raw in parsed.tags) {
      final tag = await ensureTag(writer, raw);
      if (tag != null) tags = withTag(tags, tag);
    }
    final id = await writer.insert('tasks', {
      'list_id': listId,
      'title': parsed.title,
      if (parsed.priority != null) 'priority': parsed.priority,
      if (!parsed.dates.isEmpty) ...parsed.dates.toFields(),
      if (parsed.rrule != null) 'rrule': parsed.rrule,
      if (tags.isNotEmpty) 'tags': formatTags(tags),
    });
    return CreatedTask(id: id, missingList: missing);
  });
}
