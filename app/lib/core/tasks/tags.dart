import '../sync/local_writer.dart';

/// A tag name as it is stored: trimmed, inner whitespace collapsed to one space, without a leading `#`, and without
/// commas, which separate the names in a task's `tags` cell. Null when nothing is left.
String? cleanTagName(String raw) {
  final name = raw.replaceAll(',', ' ').trim().replaceFirst(RegExp(r'^#+'), '').trim().replaceAll(RegExp(r'\s+'), ' ');
  return name.isEmpty ? null : name;
}

/// The tag names in a task's `tags` cell, in their order. Blanks are dropped, and a name repeated in another case is
/// kept once, so a cell typed by hand in the Sheet reads the same as one the app wrote.
List<String> parseTags(String? cell) {
  final names = <String>[];
  for (final part in (cell ?? '').split(',')) {
    final name = cleanTagName(part);
    if (name != null && indexOfTag(names, name) < 0) names.add(name);
  }
  return names;
}

/// The `tags` cell for [names].
String formatTags(Iterable<String> names) => names.join(',');

/// Where [name] is in [names], ignoring case, or -1. Tag names match without regard to case, as in TickTick.
int indexOfTag(List<String> names, String name) {
  final key = name.toLowerCase();
  return names.indexWhere((n) => n.toLowerCase() == key);
}

/// [tags] with [name] added at the end, unless it is already there in some case.
List<String> withTag(List<String> tags, String name) => indexOfTag(tags, name) < 0 ? [...tags, name] : tags;

/// [tags] without [name], in any case.
List<String> withoutTag(List<String> tags, String name) {
  final key = name.toLowerCase();
  return [
    for (final t in tags)
      if (t.toLowerCase() != key) t,
  ];
}

/// The name to store for the tag [raw], or null when [raw] is blank.
///
/// A tag the `tags` tab already has, in any case, is stored with that tab's spelling. A new one gets a row in the tab,
/// at the end, so it syncs to the other devices.
Future<String?> ensureTag(LocalWriter writer, String raw) async {
  final cleaned = cleanTagName(raw);
  if (cleaned == null) return null;
  final defs = (await writer.store.rowsById('tags')).values.map((r) => r.fields).where((f) => f['deleted'] != true);
  final known = defs.where((f) => (f['name'] as String? ?? '').toLowerCase() == cleaned.toLowerCase()).firstOrNull;
  final name = (known?['name'] as String?) ?? cleaned;
  if (known == null) {
    final orders = defs.map((f) => (f['sort_order'] as num?)?.toDouble() ?? 0);
    await writer.insert('tags', {'name': name, 'sort_order': orders.fold<double>(0, (m, v) => v > m ? v : m) + 1});
  }
  return name;
}

/// Adds the tag [raw] to the task [taskId] and returns the name stored, or null when [raw] is blank (see [ensureTag] for
/// how the name is chosen). The task's current `tags` value is read here rather than taken from the caller, so a change
/// that landed since the screen last drew is kept.
Future<String?> addTaskTag(LocalWriter writer, String taskId, String raw) async {
  final name = await ensureTag(writer, raw);
  if (name == null) return null;
  await _changeTags(writer, taskId, (tags) => withTag(tags, name));
  return name;
}

/// Removes the tag [name] from the task [taskId]. The tag stays in the `tags` tab for other tasks.
Future<void> removeTaskTag(LocalWriter writer, String taskId, String name) =>
    _changeTags(writer, taskId, (tags) => withoutTag(tags, name));

Future<void> _changeTags(LocalWriter writer, String taskId, List<String> Function(List<String>) change) async {
  final row = await writer.store.getRow('tasks', taskId) ?? (throw StateError('No tasks row $taskId'));
  final cell = row.fields['tags'] as String?;
  final next = formatTags(change(parseTags(cell)));
  if (next != (cell ?? '')) await writer.update('tasks', taskId, {'tags': next});
}
