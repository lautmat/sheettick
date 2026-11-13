import 'dart:convert';

import 'package:timezone/timezone.dart' as tzdb;
import 'package:uuid/uuid.dart';

import '../sync/local_writer.dart';
import '../tasks/task_dates.dart';

/// One-off import of open TickTick tasks (JSON made from the TickTick connector, kept out of git).
///
/// Nothing here touches the Sheet. [planTickTickImport] is pure and builds the rows; [applyTickTickImport] writes them
/// through the normal [LocalWriter], so the usual sync pushes them. Row ids come from the TickTick id (UUID v5), so
/// running the import again finds the rows it already made and skips them.
const _namespace = '6f1c2b8e-5f0a-4d3e-9c1b-7a2d4e8f0b11';
const _uuid = Uuid();

String importedId(String ticktickId) => _uuid.v5(_namespace, 'ticktick:$ticktickId');

class PlannedRow {
  const PlannedRow(this.tab, this.id, this.fields);
  final String tab;
  final String id;
  final Map<String, Object?> fields;
}

class ImportPlan {
  const ImportPlan({required this.rows, required this.warnings, required this.repeating});

  /// Parents come before their subtasks, so a row's parent always exists first.
  final List<PlannedRow> rows;
  final List<String> warnings;

  /// One line per repeating task, to check `repeat_from` by eye before the real run.
  final List<String> repeating;

  int get taskCount => rows.where((r) => r.tab == 'tasks').length;

  String describe() {
    final b = StringBuffer('Would write $taskCount tasks and ${rows.length - taskCount} checklist items.\n');
    for (final r in rows.where((r) => r.tab == 'tasks')) {
      final f = r.fields;
      b.writeln('- ${f['title']}  due=${f['due_at'] ?? '-'}${f['all_day'] == true ? ' (all day)' : ''}'
          '${f['tz'] != null ? ' tz=${f['tz']}' : ''}${f['parent_id'] != null ? ' [subtask]' : ''}');
    }
    if (repeating.isNotEmpty) {
      b.writeln('\nRepeating tasks (check repeat_from):');
      repeating.forEach(b.writeln);
    }
    if (warnings.isNotEmpty) {
      b.writeln('\nWarnings:');
      warnings.forEach(b.writeln);
    }
    return b.toString();
  }
}

/// Builds the rows for the TickTick tasks in [json] (a list of task objects, or `{"tasks": [...]}`), all going to
/// the list [listId] (the Inbox). Open tasks only; others are skipped with a warning.
ImportPlan planTickTickImport(String json, {required String listId}) {
  final decoded = jsonDecode(json);
  final raw = decoded is Map ? decoded['tasks'] : decoded;
  if (raw is! List) throw ArgumentError('Expected a list of tasks, or an object with a "tasks" list.');
  final tasks = raw.cast<Map<String, dynamic>>();
  final warnings = <String>[];
  final repeating = <String>[];
  final taskRows = <PlannedRow>[];
  final checkRows = <PlannedRow>[];
  final known = {for (final t in tasks) t['id'] as String};

  for (final t in tasks) {
    final tid = t['id'] as String;
    final title = (t['title'] as String?) ?? '';
    if ((t['status'] ?? 0) != 0) {
      warnings.add('Skipped "$title": status ${t['status']} is not open.');
      continue;
    }
    final parent = t['parentId'] as String?;
    final fields = <String, Object?>{
      'list_id': listId,
      'title': title,
      'kind': _kind(t['kind']),
      'priority': (t['priority'] as num?)?.toInt() ?? 0,
      'sort_order': t['sortOrder'],
      if (parent != null && known.contains(parent)) 'parent_id': importedId(parent),
      ..._dates(t, warnings),
    };
    if (parent != null && !known.contains(parent)) warnings.add('"$title": parent $parent is not in the file, imported as top level.');
    final content = (t['content'] as String?) ?? '';
    final desc = (t['desc'] as String?) ?? '';
    final note = content.isNotEmpty ? content : desc;
    if (note.isNotEmpty) fields['content'] = note;
    final tags = (t['tags'] as List?)?.cast<String>() ?? const [];
    if (tags.isNotEmpty) fields['tags'] = tags.join(',');
    final reminders = (t['reminders'] as List?)?.cast<String>() ?? const [];
    if (reminders.isNotEmpty) fields['reminders'] = jsonEncode(reminders);
    final rule = t['repeatFlag'] as String?;
    if (rule != null && rule.isNotEmpty) {
      final from = (t['repeatFrom']?.toString() == '1') ? 'COMPLETION' : 'DUE';
      fields['rrule'] = rule;
      fields['repeat_from'] = from;
      repeating.add('- $title: $rule  (TickTick repeatFrom=${t['repeatFrom']}, imported as $from)');
    }
    taskRows.add(PlannedRow('tasks', importedId(tid), fields));

    final items = (t['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final iid = (item['id'] as String?) ?? '$tid:$i';
      checkRows.add(PlannedRow('checklist', importedId(iid), {
        'task_id': importedId(tid),
        'title': item['title'],
        'status': (item['status'] as num?)?.toInt() == 1 ? 2 : 0,
        'sort_order': item['sortOrder'],
      }));
    }
  }
  // Parents first: a stable sort by depth.
  final byId = {for (final r in taskRows) r.id: r};
  int depth(PlannedRow r) {
    var d = 0;
    var p = r.fields['parent_id'] as String?;
    while (p != null && byId[p] != null && d < 10) {
      d++;
      p = byId[p]!.fields['parent_id'] as String?;
    }
    return d;
  }

  final ordered = [...taskRows]..sort((a, b) => depth(a).compareTo(depth(b)));
  return ImportPlan(rows: [...ordered, ...checkRows], warnings: warnings, repeating: repeating);
}

String _kind(Object? k) => switch (k) { 'CHECKLIST' => 'CHECKLIST', 'NOTE' => 'NOTE', _ => 'TEXT' };

Map<String, Object?> _dates(Map<String, dynamic> t, List<String> warnings) {
  final start = t['startDate'] as String?;
  final due = t['dueDate'] as String?;
  if ((start ?? '').isEmpty && (due ?? '').isEmpty) return {'all_day': false};
  final zoneName = t['timeZone'] as String?;
  final zone = locationOf(zoneName);
  final allDay = t['isAllDay'] == true;
  final floating = t['isFloating'] == true;
  if (zone == null && !floating && (zoneName ?? '').isNotEmpty) warnings.add('"${t['title']}": unknown zone $zoneName.');
  String? conv(String? s) {
    if (s == null || s.isEmpty) return null;
    final instant = _parseInstant(s);
    if (allDay) {
      // The day it is in the task's own zone; without a zone, the offset the text carries.
      final wall = zone != null ? tzdb.TZDateTime.from(instant, zone) : instant;
      final d = zone != null ? wall : _atOffset(s, instant);
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    final local = zone != null ? tzdb.TZDateTime.from(instant, zone) : instant;
    return formatWithOffset(local);
  }

  return {
    'start_at': conv(start),
    'due_at': conv(due),
    'all_day': allDay,
    'tz': (allDay || floating) ? null : zone?.name,
  };
}

DateTime _parseInstant(String s) {
  // TickTick writes +0900; Dart wants +09:00 or Z.
  final fixed = s.replaceFirstMapped(RegExp(r'([+-]\d\d)(\d\d)$'), (m) => '${m[1]}:${m[2]}');
  return DateTime.parse(fixed).toUtc();
}

DateTime _atOffset(String s, DateTime instant) {
  final m = RegExp(r'([+-])(\d\d):?(\d\d)$').firstMatch(s);
  if (m == null) return instant;
  final mins = (int.parse(m[2]!) * 60 + int.parse(m[3]!)) * (m[1] == '-' ? -1 : 1);
  return instant.add(Duration(minutes: mins));
}

/// ISO 8601 with the offset of [d] (a zoned time) or `Z` for a plain UTC value.
String formatWithOffset(DateTime d) {
  String p(int n) => n.toString().padLeft(2, '0');
  final base = '${d.year.toString().padLeft(4, '0')}-${p(d.month)}-${p(d.day)}T${p(d.hour)}:${p(d.minute)}:${p(d.second)}';
  if (d.isUtc && d is! tzdb.TZDateTime) return '${base}Z';
  final o = d.timeZoneOffset;
  final sign = o.isNegative ? '-' : '+';
  final a = o.abs();
  return '$base$sign${p(a.inHours)}:${p(a.inMinutes % 60)}';
}

class ImportResult {
  const ImportResult({required this.written, required this.skipped});
  final int written;
  final int skipped;
}

/// Writes [plan] through [writer]. Rows whose id already exists are left alone, so a second run writes nothing.
Future<ImportResult> applyTickTickImport(LocalWriter writer, ImportPlan plan) {
  return writer.store.transaction(() async {
    var written = 0, skipped = 0;
    for (final r in plan.rows) {
      if (await writer.store.getRow(r.tab, r.id) != null) {
        skipped++;
        continue;
      }
      await writer.insert(r.tab, {...r.fields, 'id': r.id});
      written++;
    }
    return ImportResult(written: written, skipped: skipped);
  });
}
