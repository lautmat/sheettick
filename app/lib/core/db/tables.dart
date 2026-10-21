import 'package:drift/drift.dart';

/// Columns shared by every entity table.
///
/// The first block mirrors the "Sync columns" of `docs/sheet-schema.md`; the second block is local
/// bookkeeping from `docs/sync-protocol.md` and is never written to the Sheet.
///
/// Conventions (see the schema doc): timestamps and dates are stored as the exact ISO 8601 text that
/// appears in the Sheet, booleans are native, and an empty Sheet cell is `null` for nullable columns and
/// the column default for the others.
mixin SyncColumns on Table {
  // Sheet columns.
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get device => text().withDefault(const Constant(''))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  // Local only.
  /// Changed locally since the last push.
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  /// Cached 1-based row number in the row's tab.
  IntColumn get sheetRow => integer().nullable()();

  /// Hash of the row's cell values as last seen in the Sheet.
  TextColumn get syncedHash => text().nullable()();

  /// JSON of the field values at the last successful sync (for the three-way merge).
  TextColumn get baseSnapshot => text().nullable()();
}

@DataClassName('Task')
@TableIndex(name: 'tasks_list_idx', columns: {#listId})
@TableIndex(name: 'tasks_parent_idx', columns: {#parentId})
@TableIndex(name: 'tasks_dirty_idx', columns: {#dirty})
class Tasks extends Table with SyncColumns {
  TextColumn get id => text()();

  /// `lists.id`. Null only for a row typed by hand in the Sheet; the sync engine assigns it to the Inbox.
  TextColumn get listId => text().nullable()();
  TextColumn get parentId => text().nullable()();
  TextColumn get sectionId => text().nullable()();

  /// `TEXT`, `CHECKLIST` or `NOTE`.
  TextColumn get kind => text().withDefault(const Constant('TEXT'))();
  TextColumn get title => text().withDefault(const Constant(''))();

  /// Markdown.
  TextColumn get content => text().withDefault(const Constant(''))();

  /// `0` none, `1` low, `3` medium, `5` high.
  IntColumn get priority => integer().withDefault(const Constant(0))();

  /// `0` open, `2` completed, `-1` won't do.
  IntColumn get status => integer().withDefault(const Constant(0))();
  TextColumn get startAt => text().nullable()();
  TextColumn get dueAt => text().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  IntColumn get durationMin => integer().nullable()();

  /// IANA time zone name; null means floating.
  TextColumn get tz => text().nullable()();
  TextColumn get rrule => text().nullable()();

  /// `DUE` or `COMPLETION`.
  TextColumn get repeatFrom => text().withDefault(const Constant('DUE'))();

  /// JSON array.
  TextColumn get exDates => text().nullable()();

  /// JSON array of iCal triggers.
  TextColumn get reminders => text().nullable()();
  BoolColumn get constantAlert => boolean().withDefault(const Constant(false))();

  /// Comma-separated tag names.
  TextColumn get tags => text().withDefault(const Constant(''))();
  RealColumn get sortOrder => real().withDefault(const Constant(0))();
  TextColumn get pinnedAt => text().nullable()();
  TextColumn get completedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// `Lists` would generate a data class named `List`, which clashes with dart:core.
@DataClassName('TaskList')
class Lists extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get folderId => text().nullable()();
  TextColumn get color => text().nullable()();

  /// `TASK` or `NOTE`.
  TextColumn get kind => text().withDefault(const Constant('TASK'))();

  /// `list`, `kanban` or `timeline`.
  TextColumn get view => text().withDefault(const Constant('list'))();
  TextColumn get groupBy => text().nullable()();
  TextColumn get orderBy => text().nullable()();
  RealColumn get sortOrder => real().withDefault(const Constant(0))();
  BoolColumn get isInbox => boolean().withDefault(const Constant(false))();
  BoolColumn get muted => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sidebar groups for lists. Table `folders`.
@DataClassName('Folder')
class Folders extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  RealColumn get sortOrder => real().withDefault(const Constant(0))();
  BoolColumn get collapsed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Groups inside a list (also the Kanban columns). Table `sections`.
@DataClassName('Section')
class Sections extends Table with SyncColumns {
  TextColumn get id => text()();

  /// `lists.id`. Nullable so a row typed by hand without one does not fail the pull.
  TextColumn get listId => text().nullable()();
  TextColumn get name => text().withDefault(const Constant(''))();
  RealColumn get sortOrder => real().withDefault(const Constant(0))();
  BoolColumn get collapsed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Checklist items of a `CHECKLIST` task. Table `checklist`.
@DataClassName('ChecklistItem')
class Checklist extends Table with SyncColumns {
  TextColumn get id => text()();

  /// `tasks.id`. Nullable for the same reason as [Sections.listId].
  TextColumn get taskId => text().nullable()();
  TextColumn get title => text().withDefault(const Constant(''))();

  /// `0` open, `2` completed.
  IntColumn get status => integer().withDefault(const Constant(0))();
  RealColumn get sortOrder => real().withDefault(const Constant(0))();
  TextColumn get startAt => text().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get completedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tag definitions (colour, nesting). Tasks keep the names in `tasks.tags`. Table `tags`.
@DataClassName('Tag')
class Tags extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get color => text().nullable()();

  /// Name of the parent tag, for nesting.
  TextColumn get parent => text().nullable()();
  RealColumn get sortOrder => real().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local mirror of the Sheet's `meta` tab (`schema_version`, `compaction_epoch`, ...).
@DataClassName('MetaEntry')
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {key};
}

/// Per-device sync state that must not be shared through the Sheet:
/// `device_id`, `last_drive_modified_time`, `last_compaction_epoch`, `spreadsheet_id`.
@DataClassName('DeviceStateEntry')
class DeviceState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
