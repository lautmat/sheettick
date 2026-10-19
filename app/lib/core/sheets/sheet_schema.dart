/// The spreadsheet layout of `docs/sheet-schema.md` (schema version 1) as data.
///
/// The doc is canonical. `test/core/sheets/sheet_schema_test.dart` parses it and fails if this file diverges.
library;

/// Value of `meta.schema_version` written by this build.
const kSheetSchemaVersion = 1;

/// Title of the spreadsheet created on first sign-in.
const kSpreadsheetTitle = 'SheetTick';

/// Drive `appProperties` tag set on the spreadsheet so it can be found again without relying on its name.
const kAppPropertyKey = 'sheettick';
const kAppPropertyValue = '1';

/// Name of the read-only formula tab for humans.
const kViewTabName = 'View';

enum ColumnType {
  uuid,
  text,
  markdown,
  enumeration,
  json,
  integer,
  number,
  boolean,
  datetime,
  date,
  timestamp;

  /// Types that must stay literal text. These columns get the Sheets "plain text" number format so a value
  /// typed by hand (`2026-10-20`, `1/2`) is not converted into a date or number.
  bool get isTextual => switch (this) {
    integer || number || boolean => false,
    _ => true,
  };
}

class ColumnSpec {
  const ColumnSpec(this.name, this.type);
  final String name;
  final ColumnType type;
}

class TabSpec {
  const TabSpec(this.name, this._columns, {this.hasSyncColumns = true});

  final String name;
  final List<ColumnSpec> _columns;

  /// Whether the sync columns are appended (every entity tab; not `meta`).
  final bool hasSyncColumns;

  /// All columns in Sheet order: the entity columns, then the sync columns.
  List<ColumnSpec> get columns => [..._columns, if (hasSyncColumns) ...kSyncColumns];

  List<String> get columnNames => [for (final c in columns) c.name];
}

const kSyncColumns = <ColumnSpec>[
  ColumnSpec('created_at', ColumnType.timestamp),
  ColumnSpec('updated_at', ColumnType.timestamp),
  ColumnSpec('version', ColumnType.integer),
  ColumnSpec('device', ColumnType.text),
  ColumnSpec('deleted', ColumnType.boolean),
];

const _id = ColumnSpec('id', ColumnType.uuid);
const _sortOrder = ColumnSpec('sort_order', ColumnType.number);

/// Entity tabs and `meta`, in the order of the doc. The `View` tab is not listed: it holds only a formula.
const kTabs = <TabSpec>[
  TabSpec('tasks', [
    _id,
    ColumnSpec('list_id', ColumnType.uuid),
    ColumnSpec('parent_id', ColumnType.uuid),
    ColumnSpec('section_id', ColumnType.uuid),
    ColumnSpec('kind', ColumnType.enumeration),
    ColumnSpec('title', ColumnType.text),
    ColumnSpec('content', ColumnType.markdown),
    ColumnSpec('priority', ColumnType.integer),
    ColumnSpec('status', ColumnType.integer),
    ColumnSpec('start_at', ColumnType.datetime),
    ColumnSpec('due_at', ColumnType.datetime),
    ColumnSpec('all_day', ColumnType.boolean),
    ColumnSpec('duration_min', ColumnType.integer),
    ColumnSpec('tz', ColumnType.text),
    ColumnSpec('rrule', ColumnType.text),
    ColumnSpec('repeat_from', ColumnType.enumeration),
    ColumnSpec('ex_dates', ColumnType.json),
    ColumnSpec('reminders', ColumnType.json),
    ColumnSpec('constant_alert', ColumnType.boolean),
    ColumnSpec('tags', ColumnType.text),
    _sortOrder,
    ColumnSpec('pinned_at', ColumnType.timestamp),
    ColumnSpec('completed_at', ColumnType.timestamp),
  ]),
  TabSpec('checklist', [
    _id,
    ColumnSpec('task_id', ColumnType.uuid),
    ColumnSpec('title', ColumnType.text),
    ColumnSpec('status', ColumnType.integer),
    _sortOrder,
    ColumnSpec('start_at', ColumnType.datetime),
    ColumnSpec('all_day', ColumnType.boolean),
    ColumnSpec('completed_at', ColumnType.timestamp),
  ]),
  TabSpec('lists', [
    _id,
    ColumnSpec('name', ColumnType.text),
    ColumnSpec('folder_id', ColumnType.uuid),
    ColumnSpec('color', ColumnType.text),
    ColumnSpec('kind', ColumnType.enumeration),
    ColumnSpec('view', ColumnType.enumeration),
    ColumnSpec('group_by', ColumnType.text),
    ColumnSpec('order_by', ColumnType.text),
    _sortOrder,
    ColumnSpec('is_inbox', ColumnType.boolean),
    ColumnSpec('muted', ColumnType.boolean),
    ColumnSpec('archived', ColumnType.boolean),
  ]),
  TabSpec('folders', [
    _id,
    ColumnSpec('name', ColumnType.text),
    _sortOrder,
    ColumnSpec('collapsed', ColumnType.boolean),
  ]),
  TabSpec('sections', [
    _id,
    ColumnSpec('list_id', ColumnType.uuid),
    ColumnSpec('name', ColumnType.text),
    _sortOrder,
    ColumnSpec('collapsed', ColumnType.boolean),
  ]),
  TabSpec('tags', [
    _id,
    ColumnSpec('name', ColumnType.text),
    ColumnSpec('color', ColumnType.text),
    ColumnSpec('parent', ColumnType.text),
    _sortOrder,
  ]),
  TabSpec('filters', [
    _id,
    ColumnSpec('name', ColumnType.text),
    ColumnSpec('rule_json', ColumnType.json),
    _sortOrder,
  ]),
  TabSpec('habits', [
    _id,
    ColumnSpec('name', ColumnType.text),
    ColumnSpec('icon', ColumnType.text),
    ColumnSpec('color', ColumnType.text),
    ColumnSpec('section', ColumnType.text),
    ColumnSpec('type', ColumnType.enumeration),
    ColumnSpec('goal', ColumnType.number),
    ColumnSpec('step', ColumnType.number),
    ColumnSpec('unit', ColumnType.text),
    ColumnSpec('rrule', ColumnType.text),
    ColumnSpec('reminders', ColumnType.json),
    ColumnSpec('constant_alert', ColumnType.boolean),
    ColumnSpec('target_days', ColumnType.integer),
    ColumnSpec('target_start', ColumnType.date),
    ColumnSpec('encouragement', ColumnType.text),
    ColumnSpec('current_streak', ColumnType.integer),
    ColumnSpec('max_streak', ColumnType.integer),
    ColumnSpec('skipped_dates', ColumnType.json),
    ColumnSpec('status', ColumnType.integer),
    ColumnSpec('archived_at', ColumnType.timestamp),
    _sortOrder,
  ]),
  TabSpec('habit_checkins', [
    _id,
    ColumnSpec('habit_id', ColumnType.uuid),
    ColumnSpec('date', ColumnType.date),
    ColumnSpec('value', ColumnType.number),
    ColumnSpec('goal', ColumnType.number),
    ColumnSpec('status', ColumnType.integer),
    ColumnSpec('note', ColumnType.text),
  ]),
  TabSpec('focus', [
    _id,
    ColumnSpec('task_id', ColumnType.uuid),
    ColumnSpec('timer_id', ColumnType.uuid),
    ColumnSpec('type', ColumnType.enumeration),
    ColumnSpec('start_at', ColumnType.timestamp),
    ColumnSpec('end_at', ColumnType.timestamp),
    ColumnSpec('pause_sec', ColumnType.integer),
    ColumnSpec('status', ColumnType.integer),
    ColumnSpec('note', ColumnType.text),
  ]),
  TabSpec('timers', [
    _id,
    ColumnSpec('name', ColumnType.text),
    ColumnSpec('type', ColumnType.enumeration),
    ColumnSpec('linked_type', ColumnType.enumeration),
    ColumnSpec('linked_id', ColumnType.uuid),
    ColumnSpec('pomo_minutes', ColumnType.integer),
    ColumnSpec('color', ColumnType.text),
    ColumnSpec('icon', ColumnType.text),
    ColumnSpec('status', ColumnType.integer),
    _sortOrder,
  ]),
  TabSpec('countdowns', [
    _id,
    ColumnSpec('name', ColumnType.text),
    ColumnSpec('type', ColumnType.enumeration),
    ColumnSpec('mode', ColumnType.enumeration),
    ColumnSpec('date', ColumnType.date),
    ColumnSpec('calendar', ColumnType.enumeration),
    ColumnSpec('ignore_year', ColumnType.boolean),
    ColumnSpec('show_age', ColumnType.boolean),
    ColumnSpec('day_one_option', ColumnType.enumeration),
    ColumnSpec('rrule', ColumnType.text),
    ColumnSpec('reminders', ColumnType.json),
    ColumnSpec('style', ColumnType.text),
    ColumnSpec('color', ColumnType.text),
    ColumnSpec('note', ColumnType.text),
    ColumnSpec('pinned_at', ColumnType.timestamp),
    ColumnSpec('archived_at', ColumnType.timestamp),
    _sortOrder,
  ]),
  TabSpec('locations', [
    _id,
    ColumnSpec('task_id', ColumnType.uuid),
    ColumnSpec('alias', ColumnType.text),
    ColumnSpec('address', ColumnType.text),
    ColumnSpec('lat', ColumnType.number),
    ColumnSpec('lng', ColumnType.number),
    ColumnSpec('radius_m', ColumnType.integer),
    ColumnSpec('trigger', ColumnType.enumeration),
  ]),
  TabSpec('attachments', [
    _id,
    ColumnSpec('task_id', ColumnType.uuid),
    ColumnSpec('drive_file_id', ColumnType.text),
    ColumnSpec('name', ColumnType.text),
    ColumnSpec('mime', ColumnType.text),
    ColumnSpec('size', ColumnType.integer),
  ]),
  TabSpec('meta', [
    ColumnSpec('key', ColumnType.text),
    ColumnSpec('value', ColumnType.text),
  ], hasSyncColumns: false),
];

/// The `View` tab: no header, only the [viewFormula] in `A1`.
const kViewTab = TabSpec(kViewTabName, [], hasSyncColumns: false);

TabSpec tabSpec(String name) => kTabs.firstWhere((t) => t.name == name);

/// Keys of the `meta` tab.
abstract final class MetaKeys {
  static const schemaVersion = 'schema_version';
  static const compactionEpoch = 'compaction_epoch';
  static const createdByAppVersion = 'created_by_app_version';
  static const settingsJson = 'settings_json';
}

/// Spreadsheet column letters: 0 → `A`, 25 → `Z`, 26 → `AA`.
String columnLetter(int index) {
  var n = index + 1;
  final letters = <String>[];
  while (n > 0) {
    letters.add(String.fromCharCode(65 + (n - 1) % 26));
    n = (n - 1) ~/ 26;
  }
  return letters.reversed.join();
}

/// The `View` tab formula: open, non-deleted tasks ordered by due date. Query columns are letters, so they
/// are derived from the `tasks` column order.
String viewFormula() {
  final cols = tabSpec('tasks').columnNames;
  String col(String name) => columnLetter(cols.indexOf(name));
  final last = columnLetter(cols.length - 1);
  return '=QUERY(tasks!A:$last, "select ${col('title')}, ${col('due_at')}, ${col('priority')}, '
      '${col('tags')}, ${col('content')} where ${col('deleted')} = FALSE and ${col('status')} = 0 '
      'order by ${col('due_at')}", 1)';
}
