// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _deviceMeta = const VerificationMeta('device');
  @override
  late final GeneratedColumn<String> device = GeneratedColumn<String>(
    'device',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sheetRowMeta = const VerificationMeta(
    'sheetRow',
  );
  @override
  late final GeneratedColumn<int> sheetRow = GeneratedColumn<int>(
    'sheet_row',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedHashMeta = const VerificationMeta(
    'syncedHash',
  );
  @override
  late final GeneratedColumn<String> syncedHash = GeneratedColumn<String>(
    'synced_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseSnapshotMeta = const VerificationMeta(
    'baseSnapshot',
  );
  @override
  late final GeneratedColumn<String> baseSnapshot = GeneratedColumn<String>(
    'base_snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('TEXT'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<String> startAt = GeneratedColumn<String>(
    'start_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<String> dueAt = GeneratedColumn<String>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
    'all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _durationMinMeta = const VerificationMeta(
    'durationMin',
  );
  @override
  late final GeneratedColumn<int> durationMin = GeneratedColumn<int>(
    'duration_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tzMeta = const VerificationMeta('tz');
  @override
  late final GeneratedColumn<String> tz = GeneratedColumn<String>(
    'tz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rruleMeta = const VerificationMeta('rrule');
  @override
  late final GeneratedColumn<String> rrule = GeneratedColumn<String>(
    'rrule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repeatFromMeta = const VerificationMeta(
    'repeatFrom',
  );
  @override
  late final GeneratedColumn<String> repeatFrom = GeneratedColumn<String>(
    'repeat_from',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('DUE'),
  );
  static const VerificationMeta _exDatesMeta = const VerificationMeta(
    'exDates',
  );
  @override
  late final GeneratedColumn<String> exDates = GeneratedColumn<String>(
    'ex_dates',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindersMeta = const VerificationMeta(
    'reminders',
  );
  @override
  late final GeneratedColumn<String> reminders = GeneratedColumn<String>(
    'reminders',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _constantAlertMeta = const VerificationMeta(
    'constantAlert',
  );
  @override
  late final GeneratedColumn<bool> constantAlert = GeneratedColumn<bool>(
    'constant_alert',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("constant_alert" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pinnedAtMeta = const VerificationMeta(
    'pinnedAt',
  );
  @override
  late final GeneratedColumn<String> pinnedAt = GeneratedColumn<String>(
    'pinned_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    version,
    device,
    deleted,
    dirty,
    sheetRow,
    syncedHash,
    baseSnapshot,
    id,
    listId,
    parentId,
    sectionId,
    kind,
    title,
    content,
    priority,
    status,
    startAt,
    dueAt,
    allDay,
    durationMin,
    tz,
    rrule,
    repeatFrom,
    exDates,
    reminders,
    constantAlert,
    tags,
    sortOrder,
    pinnedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('device')) {
      context.handle(
        _deviceMeta,
        device.isAcceptableOrUnknown(data['device']!, _deviceMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('sheet_row')) {
      context.handle(
        _sheetRowMeta,
        sheetRow.isAcceptableOrUnknown(data['sheet_row']!, _sheetRowMeta),
      );
    }
    if (data.containsKey('synced_hash')) {
      context.handle(
        _syncedHashMeta,
        syncedHash.isAcceptableOrUnknown(data['synced_hash']!, _syncedHashMeta),
      );
    }
    if (data.containsKey('base_snapshot')) {
      context.handle(
        _baseSnapshotMeta,
        baseSnapshot.isAcceptableOrUnknown(
          data['base_snapshot']!,
          _baseSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('all_day')) {
      context.handle(
        _allDayMeta,
        allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta),
      );
    }
    if (data.containsKey('duration_min')) {
      context.handle(
        _durationMinMeta,
        durationMin.isAcceptableOrUnknown(
          data['duration_min']!,
          _durationMinMeta,
        ),
      );
    }
    if (data.containsKey('tz')) {
      context.handle(_tzMeta, tz.isAcceptableOrUnknown(data['tz']!, _tzMeta));
    }
    if (data.containsKey('rrule')) {
      context.handle(
        _rruleMeta,
        rrule.isAcceptableOrUnknown(data['rrule']!, _rruleMeta),
      );
    }
    if (data.containsKey('repeat_from')) {
      context.handle(
        _repeatFromMeta,
        repeatFrom.isAcceptableOrUnknown(data['repeat_from']!, _repeatFromMeta),
      );
    }
    if (data.containsKey('ex_dates')) {
      context.handle(
        _exDatesMeta,
        exDates.isAcceptableOrUnknown(data['ex_dates']!, _exDatesMeta),
      );
    }
    if (data.containsKey('reminders')) {
      context.handle(
        _remindersMeta,
        reminders.isAcceptableOrUnknown(data['reminders']!, _remindersMeta),
      );
    }
    if (data.containsKey('constant_alert')) {
      context.handle(
        _constantAlertMeta,
        constantAlert.isAcceptableOrUnknown(
          data['constant_alert']!,
          _constantAlertMeta,
        ),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('pinned_at')) {
      context.handle(
        _pinnedAtMeta,
        pinnedAt.isAcceptableOrUnknown(data['pinned_at']!, _pinnedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      device: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      sheetRow: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sheet_row'],
      ),
      syncedHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synced_hash'],
      ),
      baseSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_snapshot'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_at'],
      ),
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_at'],
      ),
      allDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}all_day'],
      )!,
      durationMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_min'],
      ),
      tz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tz'],
      ),
      rrule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rrule'],
      ),
      repeatFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_from'],
      )!,
      exDates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ex_dates'],
      ),
      reminders: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminders'],
      ),
      constantAlert: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}constant_alert'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      pinnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pinned_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class Task extends DataClass implements Insertable<Task> {
  final String createdAt;
  final String updatedAt;
  final int version;
  final String device;
  final bool deleted;

  /// Changed locally since the last push.
  final bool dirty;

  /// Cached 1-based row number in the row's tab.
  final int? sheetRow;

  /// Hash of the row's cell values as last seen in the Sheet.
  final String? syncedHash;

  /// JSON of the field values at the last successful sync (for the three-way merge).
  final String? baseSnapshot;
  final String id;

  /// `lists.id`. Null only for a row typed by hand in the Sheet; the sync engine assigns it to the Inbox.
  final String? listId;
  final String? parentId;
  final String? sectionId;

  /// `TEXT`, `CHECKLIST` or `NOTE`.
  final String kind;
  final String title;

  /// Markdown.
  final String content;

  /// `0` none, `1` low, `3` medium, `5` high.
  final int priority;

  /// `0` open, `2` completed, `-1` won't do.
  final int status;
  final String? startAt;
  final String? dueAt;
  final bool allDay;
  final int? durationMin;

  /// IANA time zone name; null means floating.
  final String? tz;
  final String? rrule;

  /// `DUE` or `COMPLETION`.
  final String repeatFrom;

  /// JSON array.
  final String? exDates;

  /// JSON array of iCal triggers.
  final String? reminders;
  final bool constantAlert;

  /// Comma-separated tag names.
  final String tags;
  final double sortOrder;
  final String? pinnedAt;
  final String? completedAt;
  const Task({
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.device,
    required this.deleted,
    required this.dirty,
    this.sheetRow,
    this.syncedHash,
    this.baseSnapshot,
    required this.id,
    this.listId,
    this.parentId,
    this.sectionId,
    required this.kind,
    required this.title,
    required this.content,
    required this.priority,
    required this.status,
    this.startAt,
    this.dueAt,
    required this.allDay,
    this.durationMin,
    this.tz,
    this.rrule,
    required this.repeatFrom,
    this.exDates,
    this.reminders,
    required this.constantAlert,
    required this.tags,
    required this.sortOrder,
    this.pinnedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['version'] = Variable<int>(version);
    map['device'] = Variable<String>(device);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || sheetRow != null) {
      map['sheet_row'] = Variable<int>(sheetRow);
    }
    if (!nullToAbsent || syncedHash != null) {
      map['synced_hash'] = Variable<String>(syncedHash);
    }
    if (!nullToAbsent || baseSnapshot != null) {
      map['base_snapshot'] = Variable<String>(baseSnapshot);
    }
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || listId != null) {
      map['list_id'] = Variable<String>(listId);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    if (!nullToAbsent || sectionId != null) {
      map['section_id'] = Variable<String>(sectionId);
    }
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['priority'] = Variable<int>(priority);
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || startAt != null) {
      map['start_at'] = Variable<String>(startAt);
    }
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<String>(dueAt);
    }
    map['all_day'] = Variable<bool>(allDay);
    if (!nullToAbsent || durationMin != null) {
      map['duration_min'] = Variable<int>(durationMin);
    }
    if (!nullToAbsent || tz != null) {
      map['tz'] = Variable<String>(tz);
    }
    if (!nullToAbsent || rrule != null) {
      map['rrule'] = Variable<String>(rrule);
    }
    map['repeat_from'] = Variable<String>(repeatFrom);
    if (!nullToAbsent || exDates != null) {
      map['ex_dates'] = Variable<String>(exDates);
    }
    if (!nullToAbsent || reminders != null) {
      map['reminders'] = Variable<String>(reminders);
    }
    map['constant_alert'] = Variable<bool>(constantAlert);
    map['tags'] = Variable<String>(tags);
    map['sort_order'] = Variable<double>(sortOrder);
    if (!nullToAbsent || pinnedAt != null) {
      map['pinned_at'] = Variable<String>(pinnedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<String>(completedAt);
    }
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: Value(version),
      device: Value(device),
      deleted: Value(deleted),
      dirty: Value(dirty),
      sheetRow: sheetRow == null && nullToAbsent
          ? const Value.absent()
          : Value(sheetRow),
      syncedHash: syncedHash == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedHash),
      baseSnapshot: baseSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(baseSnapshot),
      id: Value(id),
      listId: listId == null && nullToAbsent
          ? const Value.absent()
          : Value(listId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      sectionId: sectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sectionId),
      kind: Value(kind),
      title: Value(title),
      content: Value(content),
      priority: Value(priority),
      status: Value(status),
      startAt: startAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startAt),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      allDay: Value(allDay),
      durationMin: durationMin == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMin),
      tz: tz == null && nullToAbsent ? const Value.absent() : Value(tz),
      rrule: rrule == null && nullToAbsent
          ? const Value.absent()
          : Value(rrule),
      repeatFrom: Value(repeatFrom),
      exDates: exDates == null && nullToAbsent
          ? const Value.absent()
          : Value(exDates),
      reminders: reminders == null && nullToAbsent
          ? const Value.absent()
          : Value(reminders),
      constantAlert: Value(constantAlert),
      tags: Value(tags),
      sortOrder: Value(sortOrder),
      pinnedAt: pinnedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pinnedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory Task.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
      device: serializer.fromJson<String>(json['device']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      sheetRow: serializer.fromJson<int?>(json['sheetRow']),
      syncedHash: serializer.fromJson<String?>(json['syncedHash']),
      baseSnapshot: serializer.fromJson<String?>(json['baseSnapshot']),
      id: serializer.fromJson<String>(json['id']),
      listId: serializer.fromJson<String?>(json['listId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      sectionId: serializer.fromJson<String?>(json['sectionId']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      priority: serializer.fromJson<int>(json['priority']),
      status: serializer.fromJson<int>(json['status']),
      startAt: serializer.fromJson<String?>(json['startAt']),
      dueAt: serializer.fromJson<String?>(json['dueAt']),
      allDay: serializer.fromJson<bool>(json['allDay']),
      durationMin: serializer.fromJson<int?>(json['durationMin']),
      tz: serializer.fromJson<String?>(json['tz']),
      rrule: serializer.fromJson<String?>(json['rrule']),
      repeatFrom: serializer.fromJson<String>(json['repeatFrom']),
      exDates: serializer.fromJson<String?>(json['exDates']),
      reminders: serializer.fromJson<String?>(json['reminders']),
      constantAlert: serializer.fromJson<bool>(json['constantAlert']),
      tags: serializer.fromJson<String>(json['tags']),
      sortOrder: serializer.fromJson<double>(json['sortOrder']),
      pinnedAt: serializer.fromJson<String?>(json['pinnedAt']),
      completedAt: serializer.fromJson<String?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'version': serializer.toJson<int>(version),
      'device': serializer.toJson<String>(device),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'sheetRow': serializer.toJson<int?>(sheetRow),
      'syncedHash': serializer.toJson<String?>(syncedHash),
      'baseSnapshot': serializer.toJson<String?>(baseSnapshot),
      'id': serializer.toJson<String>(id),
      'listId': serializer.toJson<String?>(listId),
      'parentId': serializer.toJson<String?>(parentId),
      'sectionId': serializer.toJson<String?>(sectionId),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'priority': serializer.toJson<int>(priority),
      'status': serializer.toJson<int>(status),
      'startAt': serializer.toJson<String?>(startAt),
      'dueAt': serializer.toJson<String?>(dueAt),
      'allDay': serializer.toJson<bool>(allDay),
      'durationMin': serializer.toJson<int?>(durationMin),
      'tz': serializer.toJson<String?>(tz),
      'rrule': serializer.toJson<String?>(rrule),
      'repeatFrom': serializer.toJson<String>(repeatFrom),
      'exDates': serializer.toJson<String?>(exDates),
      'reminders': serializer.toJson<String?>(reminders),
      'constantAlert': serializer.toJson<bool>(constantAlert),
      'tags': serializer.toJson<String>(tags),
      'sortOrder': serializer.toJson<double>(sortOrder),
      'pinnedAt': serializer.toJson<String?>(pinnedAt),
      'completedAt': serializer.toJson<String?>(completedAt),
    };
  }

  Task copyWith({
    String? createdAt,
    String? updatedAt,
    int? version,
    String? device,
    bool? deleted,
    bool? dirty,
    Value<int?> sheetRow = const Value.absent(),
    Value<String?> syncedHash = const Value.absent(),
    Value<String?> baseSnapshot = const Value.absent(),
    String? id,
    Value<String?> listId = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
    Value<String?> sectionId = const Value.absent(),
    String? kind,
    String? title,
    String? content,
    int? priority,
    int? status,
    Value<String?> startAt = const Value.absent(),
    Value<String?> dueAt = const Value.absent(),
    bool? allDay,
    Value<int?> durationMin = const Value.absent(),
    Value<String?> tz = const Value.absent(),
    Value<String?> rrule = const Value.absent(),
    String? repeatFrom,
    Value<String?> exDates = const Value.absent(),
    Value<String?> reminders = const Value.absent(),
    bool? constantAlert,
    String? tags,
    double? sortOrder,
    Value<String?> pinnedAt = const Value.absent(),
    Value<String?> completedAt = const Value.absent(),
  }) => Task(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    device: device ?? this.device,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    sheetRow: sheetRow.present ? sheetRow.value : this.sheetRow,
    syncedHash: syncedHash.present ? syncedHash.value : this.syncedHash,
    baseSnapshot: baseSnapshot.present ? baseSnapshot.value : this.baseSnapshot,
    id: id ?? this.id,
    listId: listId.present ? listId.value : this.listId,
    parentId: parentId.present ? parentId.value : this.parentId,
    sectionId: sectionId.present ? sectionId.value : this.sectionId,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    content: content ?? this.content,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    startAt: startAt.present ? startAt.value : this.startAt,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    allDay: allDay ?? this.allDay,
    durationMin: durationMin.present ? durationMin.value : this.durationMin,
    tz: tz.present ? tz.value : this.tz,
    rrule: rrule.present ? rrule.value : this.rrule,
    repeatFrom: repeatFrom ?? this.repeatFrom,
    exDates: exDates.present ? exDates.value : this.exDates,
    reminders: reminders.present ? reminders.value : this.reminders,
    constantAlert: constantAlert ?? this.constantAlert,
    tags: tags ?? this.tags,
    sortOrder: sortOrder ?? this.sortOrder,
    pinnedAt: pinnedAt.present ? pinnedAt.value : this.pinnedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      device: data.device.present ? data.device.value : this.device,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      sheetRow: data.sheetRow.present ? data.sheetRow.value : this.sheetRow,
      syncedHash: data.syncedHash.present
          ? data.syncedHash.value
          : this.syncedHash,
      baseSnapshot: data.baseSnapshot.present
          ? data.baseSnapshot.value
          : this.baseSnapshot,
      id: data.id.present ? data.id.value : this.id,
      listId: data.listId.present ? data.listId.value : this.listId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      priority: data.priority.present ? data.priority.value : this.priority,
      status: data.status.present ? data.status.value : this.status,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      allDay: data.allDay.present ? data.allDay.value : this.allDay,
      durationMin: data.durationMin.present
          ? data.durationMin.value
          : this.durationMin,
      tz: data.tz.present ? data.tz.value : this.tz,
      rrule: data.rrule.present ? data.rrule.value : this.rrule,
      repeatFrom: data.repeatFrom.present
          ? data.repeatFrom.value
          : this.repeatFrom,
      exDates: data.exDates.present ? data.exDates.value : this.exDates,
      reminders: data.reminders.present ? data.reminders.value : this.reminders,
      constantAlert: data.constantAlert.present
          ? data.constantAlert.value
          : this.constantAlert,
      tags: data.tags.present ? data.tags.value : this.tags,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      pinnedAt: data.pinnedAt.present ? data.pinnedAt.value : this.pinnedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('device: $device, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('sheetRow: $sheetRow, ')
          ..write('syncedHash: $syncedHash, ')
          ..write('baseSnapshot: $baseSnapshot, ')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('parentId: $parentId, ')
          ..write('sectionId: $sectionId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('startAt: $startAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('allDay: $allDay, ')
          ..write('durationMin: $durationMin, ')
          ..write('tz: $tz, ')
          ..write('rrule: $rrule, ')
          ..write('repeatFrom: $repeatFrom, ')
          ..write('exDates: $exDates, ')
          ..write('reminders: $reminders, ')
          ..write('constantAlert: $constantAlert, ')
          ..write('tags: $tags, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    createdAt,
    updatedAt,
    version,
    device,
    deleted,
    dirty,
    sheetRow,
    syncedHash,
    baseSnapshot,
    id,
    listId,
    parentId,
    sectionId,
    kind,
    title,
    content,
    priority,
    status,
    startAt,
    dueAt,
    allDay,
    durationMin,
    tz,
    rrule,
    repeatFrom,
    exDates,
    reminders,
    constantAlert,
    tags,
    sortOrder,
    pinnedAt,
    completedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.device == this.device &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.sheetRow == this.sheetRow &&
          other.syncedHash == this.syncedHash &&
          other.baseSnapshot == this.baseSnapshot &&
          other.id == this.id &&
          other.listId == this.listId &&
          other.parentId == this.parentId &&
          other.sectionId == this.sectionId &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.content == this.content &&
          other.priority == this.priority &&
          other.status == this.status &&
          other.startAt == this.startAt &&
          other.dueAt == this.dueAt &&
          other.allDay == this.allDay &&
          other.durationMin == this.durationMin &&
          other.tz == this.tz &&
          other.rrule == this.rrule &&
          other.repeatFrom == this.repeatFrom &&
          other.exDates == this.exDates &&
          other.reminders == this.reminders &&
          other.constantAlert == this.constantAlert &&
          other.tags == this.tags &&
          other.sortOrder == this.sortOrder &&
          other.pinnedAt == this.pinnedAt &&
          other.completedAt == this.completedAt);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> version;
  final Value<String> device;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> sheetRow;
  final Value<String?> syncedHash;
  final Value<String?> baseSnapshot;
  final Value<String> id;
  final Value<String?> listId;
  final Value<String?> parentId;
  final Value<String?> sectionId;
  final Value<String> kind;
  final Value<String> title;
  final Value<String> content;
  final Value<int> priority;
  final Value<int> status;
  final Value<String?> startAt;
  final Value<String?> dueAt;
  final Value<bool> allDay;
  final Value<int?> durationMin;
  final Value<String?> tz;
  final Value<String?> rrule;
  final Value<String> repeatFrom;
  final Value<String?> exDates;
  final Value<String?> reminders;
  final Value<bool> constantAlert;
  final Value<String> tags;
  final Value<double> sortOrder;
  final Value<String?> pinnedAt;
  final Value<String?> completedAt;
  final Value<int> rowid;
  const TasksCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.device = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.sheetRow = const Value.absent(),
    this.syncedHash = const Value.absent(),
    this.baseSnapshot = const Value.absent(),
    this.id = const Value.absent(),
    this.listId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.startAt = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.tz = const Value.absent(),
    this.rrule = const Value.absent(),
    this.repeatFrom = const Value.absent(),
    this.exDates = const Value.absent(),
    this.reminders = const Value.absent(),
    this.constantAlert = const Value.absent(),
    this.tags = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String createdAt,
    required String updatedAt,
    this.version = const Value.absent(),
    this.device = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.sheetRow = const Value.absent(),
    this.syncedHash = const Value.absent(),
    this.baseSnapshot = const Value.absent(),
    required String id,
    this.listId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.startAt = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.tz = const Value.absent(),
    this.rrule = const Value.absent(),
    this.repeatFrom = const Value.absent(),
    this.exDates = const Value.absent(),
    this.reminders = const Value.absent(),
    this.constantAlert = const Value.absent(),
    this.tags = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       id = Value(id);
  static Insertable<Task> custom({
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? version,
    Expression<String>? device,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? sheetRow,
    Expression<String>? syncedHash,
    Expression<String>? baseSnapshot,
    Expression<String>? id,
    Expression<String>? listId,
    Expression<String>? parentId,
    Expression<String>? sectionId,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? content,
    Expression<int>? priority,
    Expression<int>? status,
    Expression<String>? startAt,
    Expression<String>? dueAt,
    Expression<bool>? allDay,
    Expression<int>? durationMin,
    Expression<String>? tz,
    Expression<String>? rrule,
    Expression<String>? repeatFrom,
    Expression<String>? exDates,
    Expression<String>? reminders,
    Expression<bool>? constantAlert,
    Expression<String>? tags,
    Expression<double>? sortOrder,
    Expression<String>? pinnedAt,
    Expression<String>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (device != null) 'device': device,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (sheetRow != null) 'sheet_row': sheetRow,
      if (syncedHash != null) 'synced_hash': syncedHash,
      if (baseSnapshot != null) 'base_snapshot': baseSnapshot,
      if (id != null) 'id': id,
      if (listId != null) 'list_id': listId,
      if (parentId != null) 'parent_id': parentId,
      if (sectionId != null) 'section_id': sectionId,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (startAt != null) 'start_at': startAt,
      if (dueAt != null) 'due_at': dueAt,
      if (allDay != null) 'all_day': allDay,
      if (durationMin != null) 'duration_min': durationMin,
      if (tz != null) 'tz': tz,
      if (rrule != null) 'rrule': rrule,
      if (repeatFrom != null) 'repeat_from': repeatFrom,
      if (exDates != null) 'ex_dates': exDates,
      if (reminders != null) 'reminders': reminders,
      if (constantAlert != null) 'constant_alert': constantAlert,
      if (tags != null) 'tags': tags,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (pinnedAt != null) 'pinned_at': pinnedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? version,
    Value<String>? device,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<int?>? sheetRow,
    Value<String?>? syncedHash,
    Value<String?>? baseSnapshot,
    Value<String>? id,
    Value<String?>? listId,
    Value<String?>? parentId,
    Value<String?>? sectionId,
    Value<String>? kind,
    Value<String>? title,
    Value<String>? content,
    Value<int>? priority,
    Value<int>? status,
    Value<String?>? startAt,
    Value<String?>? dueAt,
    Value<bool>? allDay,
    Value<int?>? durationMin,
    Value<String?>? tz,
    Value<String?>? rrule,
    Value<String>? repeatFrom,
    Value<String?>? exDates,
    Value<String?>? reminders,
    Value<bool>? constantAlert,
    Value<String>? tags,
    Value<double>? sortOrder,
    Value<String?>? pinnedAt,
    Value<String?>? completedAt,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      device: device ?? this.device,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      sheetRow: sheetRow ?? this.sheetRow,
      syncedHash: syncedHash ?? this.syncedHash,
      baseSnapshot: baseSnapshot ?? this.baseSnapshot,
      id: id ?? this.id,
      listId: listId ?? this.listId,
      parentId: parentId ?? this.parentId,
      sectionId: sectionId ?? this.sectionId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      content: content ?? this.content,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      startAt: startAt ?? this.startAt,
      dueAt: dueAt ?? this.dueAt,
      allDay: allDay ?? this.allDay,
      durationMin: durationMin ?? this.durationMin,
      tz: tz ?? this.tz,
      rrule: rrule ?? this.rrule,
      repeatFrom: repeatFrom ?? this.repeatFrom,
      exDates: exDates ?? this.exDates,
      reminders: reminders ?? this.reminders,
      constantAlert: constantAlert ?? this.constantAlert,
      tags: tags ?? this.tags,
      sortOrder: sortOrder ?? this.sortOrder,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (device.present) {
      map['device'] = Variable<String>(device.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (sheetRow.present) {
      map['sheet_row'] = Variable<int>(sheetRow.value);
    }
    if (syncedHash.present) {
      map['synced_hash'] = Variable<String>(syncedHash.value);
    }
    if (baseSnapshot.present) {
      map['base_snapshot'] = Variable<String>(baseSnapshot.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<String>(startAt.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<String>(dueAt.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (durationMin.present) {
      map['duration_min'] = Variable<int>(durationMin.value);
    }
    if (tz.present) {
      map['tz'] = Variable<String>(tz.value);
    }
    if (rrule.present) {
      map['rrule'] = Variable<String>(rrule.value);
    }
    if (repeatFrom.present) {
      map['repeat_from'] = Variable<String>(repeatFrom.value);
    }
    if (exDates.present) {
      map['ex_dates'] = Variable<String>(exDates.value);
    }
    if (reminders.present) {
      map['reminders'] = Variable<String>(reminders.value);
    }
    if (constantAlert.present) {
      map['constant_alert'] = Variable<bool>(constantAlert.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (pinnedAt.present) {
      map['pinned_at'] = Variable<String>(pinnedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('device: $device, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('sheetRow: $sheetRow, ')
          ..write('syncedHash: $syncedHash, ')
          ..write('baseSnapshot: $baseSnapshot, ')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('parentId: $parentId, ')
          ..write('sectionId: $sectionId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('startAt: $startAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('allDay: $allDay, ')
          ..write('durationMin: $durationMin, ')
          ..write('tz: $tz, ')
          ..write('rrule: $rrule, ')
          ..write('repeatFrom: $repeatFrom, ')
          ..write('exDates: $exDates, ')
          ..write('reminders: $reminders, ')
          ..write('constantAlert: $constantAlert, ')
          ..write('tags: $tags, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ListsTable extends Lists with TableInfo<$ListsTable, TaskList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _deviceMeta = const VerificationMeta('device');
  @override
  late final GeneratedColumn<String> device = GeneratedColumn<String>(
    'device',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sheetRowMeta = const VerificationMeta(
    'sheetRow',
  );
  @override
  late final GeneratedColumn<int> sheetRow = GeneratedColumn<int>(
    'sheet_row',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedHashMeta = const VerificationMeta(
    'syncedHash',
  );
  @override
  late final GeneratedColumn<String> syncedHash = GeneratedColumn<String>(
    'synced_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseSnapshotMeta = const VerificationMeta(
    'baseSnapshot',
  );
  @override
  late final GeneratedColumn<String> baseSnapshot = GeneratedColumn<String>(
    'base_snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('TASK'),
  );
  static const VerificationMeta _viewMeta = const VerificationMeta('view');
  @override
  late final GeneratedColumn<String> view = GeneratedColumn<String>(
    'view',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('list'),
  );
  static const VerificationMeta _groupByMeta = const VerificationMeta(
    'groupBy',
  );
  @override
  late final GeneratedColumn<String> groupBy = GeneratedColumn<String>(
    'group_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderByMeta = const VerificationMeta(
    'orderBy',
  );
  @override
  late final GeneratedColumn<String> orderBy = GeneratedColumn<String>(
    'order_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isInboxMeta = const VerificationMeta(
    'isInbox',
  );
  @override
  late final GeneratedColumn<bool> isInbox = GeneratedColumn<bool>(
    'is_inbox',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_inbox" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _mutedMeta = const VerificationMeta('muted');
  @override
  late final GeneratedColumn<bool> muted = GeneratedColumn<bool>(
    'muted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("muted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    version,
    device,
    deleted,
    dirty,
    sheetRow,
    syncedHash,
    baseSnapshot,
    id,
    name,
    folderId,
    color,
    kind,
    view,
    groupBy,
    orderBy,
    sortOrder,
    isInbox,
    muted,
    archived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('device')) {
      context.handle(
        _deviceMeta,
        device.isAcceptableOrUnknown(data['device']!, _deviceMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('sheet_row')) {
      context.handle(
        _sheetRowMeta,
        sheetRow.isAcceptableOrUnknown(data['sheet_row']!, _sheetRowMeta),
      );
    }
    if (data.containsKey('synced_hash')) {
      context.handle(
        _syncedHashMeta,
        syncedHash.isAcceptableOrUnknown(data['synced_hash']!, _syncedHashMeta),
      );
    }
    if (data.containsKey('base_snapshot')) {
      context.handle(
        _baseSnapshotMeta,
        baseSnapshot.isAcceptableOrUnknown(
          data['base_snapshot']!,
          _baseSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('view')) {
      context.handle(
        _viewMeta,
        view.isAcceptableOrUnknown(data['view']!, _viewMeta),
      );
    }
    if (data.containsKey('group_by')) {
      context.handle(
        _groupByMeta,
        groupBy.isAcceptableOrUnknown(data['group_by']!, _groupByMeta),
      );
    }
    if (data.containsKey('order_by')) {
      context.handle(
        _orderByMeta,
        orderBy.isAcceptableOrUnknown(data['order_by']!, _orderByMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_inbox')) {
      context.handle(
        _isInboxMeta,
        isInbox.isAcceptableOrUnknown(data['is_inbox']!, _isInboxMeta),
      );
    }
    if (data.containsKey('muted')) {
      context.handle(
        _mutedMeta,
        muted.isAcceptableOrUnknown(data['muted']!, _mutedMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskList(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      device: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      sheetRow: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sheet_row'],
      ),
      syncedHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synced_hash'],
      ),
      baseSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_snapshot'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      view: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}view'],
      )!,
      groupBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_by'],
      ),
      orderBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_by'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      isInbox: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_inbox'],
      )!,
      muted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}muted'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
    );
  }

  @override
  $ListsTable createAlias(String alias) {
    return $ListsTable(attachedDatabase, alias);
  }
}

class TaskList extends DataClass implements Insertable<TaskList> {
  final String createdAt;
  final String updatedAt;
  final int version;
  final String device;
  final bool deleted;

  /// Changed locally since the last push.
  final bool dirty;

  /// Cached 1-based row number in the row's tab.
  final int? sheetRow;

  /// Hash of the row's cell values as last seen in the Sheet.
  final String? syncedHash;

  /// JSON of the field values at the last successful sync (for the three-way merge).
  final String? baseSnapshot;
  final String id;
  final String name;
  final String? folderId;
  final String? color;

  /// `TASK` or `NOTE`.
  final String kind;

  /// `list`, `kanban` or `timeline`.
  final String view;
  final String? groupBy;
  final String? orderBy;
  final double sortOrder;
  final bool isInbox;
  final bool muted;
  final bool archived;
  const TaskList({
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.device,
    required this.deleted,
    required this.dirty,
    this.sheetRow,
    this.syncedHash,
    this.baseSnapshot,
    required this.id,
    required this.name,
    this.folderId,
    this.color,
    required this.kind,
    required this.view,
    this.groupBy,
    this.orderBy,
    required this.sortOrder,
    required this.isInbox,
    required this.muted,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['version'] = Variable<int>(version);
    map['device'] = Variable<String>(device);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || sheetRow != null) {
      map['sheet_row'] = Variable<int>(sheetRow);
    }
    if (!nullToAbsent || syncedHash != null) {
      map['synced_hash'] = Variable<String>(syncedHash);
    }
    if (!nullToAbsent || baseSnapshot != null) {
      map['base_snapshot'] = Variable<String>(baseSnapshot);
    }
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['kind'] = Variable<String>(kind);
    map['view'] = Variable<String>(view);
    if (!nullToAbsent || groupBy != null) {
      map['group_by'] = Variable<String>(groupBy);
    }
    if (!nullToAbsent || orderBy != null) {
      map['order_by'] = Variable<String>(orderBy);
    }
    map['sort_order'] = Variable<double>(sortOrder);
    map['is_inbox'] = Variable<bool>(isInbox);
    map['muted'] = Variable<bool>(muted);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  ListsCompanion toCompanion(bool nullToAbsent) {
    return ListsCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: Value(version),
      device: Value(device),
      deleted: Value(deleted),
      dirty: Value(dirty),
      sheetRow: sheetRow == null && nullToAbsent
          ? const Value.absent()
          : Value(sheetRow),
      syncedHash: syncedHash == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedHash),
      baseSnapshot: baseSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(baseSnapshot),
      id: Value(id),
      name: Value(name),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      kind: Value(kind),
      view: Value(view),
      groupBy: groupBy == null && nullToAbsent
          ? const Value.absent()
          : Value(groupBy),
      orderBy: orderBy == null && nullToAbsent
          ? const Value.absent()
          : Value(orderBy),
      sortOrder: Value(sortOrder),
      isInbox: Value(isInbox),
      muted: Value(muted),
      archived: Value(archived),
    );
  }

  factory TaskList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskList(
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
      device: serializer.fromJson<String>(json['device']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      sheetRow: serializer.fromJson<int?>(json['sheetRow']),
      syncedHash: serializer.fromJson<String?>(json['syncedHash']),
      baseSnapshot: serializer.fromJson<String?>(json['baseSnapshot']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      color: serializer.fromJson<String?>(json['color']),
      kind: serializer.fromJson<String>(json['kind']),
      view: serializer.fromJson<String>(json['view']),
      groupBy: serializer.fromJson<String?>(json['groupBy']),
      orderBy: serializer.fromJson<String?>(json['orderBy']),
      sortOrder: serializer.fromJson<double>(json['sortOrder']),
      isInbox: serializer.fromJson<bool>(json['isInbox']),
      muted: serializer.fromJson<bool>(json['muted']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'version': serializer.toJson<int>(version),
      'device': serializer.toJson<String>(device),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'sheetRow': serializer.toJson<int?>(sheetRow),
      'syncedHash': serializer.toJson<String?>(syncedHash),
      'baseSnapshot': serializer.toJson<String?>(baseSnapshot),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'folderId': serializer.toJson<String?>(folderId),
      'color': serializer.toJson<String?>(color),
      'kind': serializer.toJson<String>(kind),
      'view': serializer.toJson<String>(view),
      'groupBy': serializer.toJson<String?>(groupBy),
      'orderBy': serializer.toJson<String?>(orderBy),
      'sortOrder': serializer.toJson<double>(sortOrder),
      'isInbox': serializer.toJson<bool>(isInbox),
      'muted': serializer.toJson<bool>(muted),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  TaskList copyWith({
    String? createdAt,
    String? updatedAt,
    int? version,
    String? device,
    bool? deleted,
    bool? dirty,
    Value<int?> sheetRow = const Value.absent(),
    Value<String?> syncedHash = const Value.absent(),
    Value<String?> baseSnapshot = const Value.absent(),
    String? id,
    String? name,
    Value<String?> folderId = const Value.absent(),
    Value<String?> color = const Value.absent(),
    String? kind,
    String? view,
    Value<String?> groupBy = const Value.absent(),
    Value<String?> orderBy = const Value.absent(),
    double? sortOrder,
    bool? isInbox,
    bool? muted,
    bool? archived,
  }) => TaskList(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    device: device ?? this.device,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    sheetRow: sheetRow.present ? sheetRow.value : this.sheetRow,
    syncedHash: syncedHash.present ? syncedHash.value : this.syncedHash,
    baseSnapshot: baseSnapshot.present ? baseSnapshot.value : this.baseSnapshot,
    id: id ?? this.id,
    name: name ?? this.name,
    folderId: folderId.present ? folderId.value : this.folderId,
    color: color.present ? color.value : this.color,
    kind: kind ?? this.kind,
    view: view ?? this.view,
    groupBy: groupBy.present ? groupBy.value : this.groupBy,
    orderBy: orderBy.present ? orderBy.value : this.orderBy,
    sortOrder: sortOrder ?? this.sortOrder,
    isInbox: isInbox ?? this.isInbox,
    muted: muted ?? this.muted,
    archived: archived ?? this.archived,
  );
  TaskList copyWithCompanion(ListsCompanion data) {
    return TaskList(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      device: data.device.present ? data.device.value : this.device,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      sheetRow: data.sheetRow.present ? data.sheetRow.value : this.sheetRow,
      syncedHash: data.syncedHash.present
          ? data.syncedHash.value
          : this.syncedHash,
      baseSnapshot: data.baseSnapshot.present
          ? data.baseSnapshot.value
          : this.baseSnapshot,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      color: data.color.present ? data.color.value : this.color,
      kind: data.kind.present ? data.kind.value : this.kind,
      view: data.view.present ? data.view.value : this.view,
      groupBy: data.groupBy.present ? data.groupBy.value : this.groupBy,
      orderBy: data.orderBy.present ? data.orderBy.value : this.orderBy,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isInbox: data.isInbox.present ? data.isInbox.value : this.isInbox,
      muted: data.muted.present ? data.muted.value : this.muted,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskList(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('device: $device, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('sheetRow: $sheetRow, ')
          ..write('syncedHash: $syncedHash, ')
          ..write('baseSnapshot: $baseSnapshot, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('folderId: $folderId, ')
          ..write('color: $color, ')
          ..write('kind: $kind, ')
          ..write('view: $view, ')
          ..write('groupBy: $groupBy, ')
          ..write('orderBy: $orderBy, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isInbox: $isInbox, ')
          ..write('muted: $muted, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    createdAt,
    updatedAt,
    version,
    device,
    deleted,
    dirty,
    sheetRow,
    syncedHash,
    baseSnapshot,
    id,
    name,
    folderId,
    color,
    kind,
    view,
    groupBy,
    orderBy,
    sortOrder,
    isInbox,
    muted,
    archived,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskList &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.device == this.device &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.sheetRow == this.sheetRow &&
          other.syncedHash == this.syncedHash &&
          other.baseSnapshot == this.baseSnapshot &&
          other.id == this.id &&
          other.name == this.name &&
          other.folderId == this.folderId &&
          other.color == this.color &&
          other.kind == this.kind &&
          other.view == this.view &&
          other.groupBy == this.groupBy &&
          other.orderBy == this.orderBy &&
          other.sortOrder == this.sortOrder &&
          other.isInbox == this.isInbox &&
          other.muted == this.muted &&
          other.archived == this.archived);
}

class ListsCompanion extends UpdateCompanion<TaskList> {
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> version;
  final Value<String> device;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> sheetRow;
  final Value<String?> syncedHash;
  final Value<String?> baseSnapshot;
  final Value<String> id;
  final Value<String> name;
  final Value<String?> folderId;
  final Value<String?> color;
  final Value<String> kind;
  final Value<String> view;
  final Value<String?> groupBy;
  final Value<String?> orderBy;
  final Value<double> sortOrder;
  final Value<bool> isInbox;
  final Value<bool> muted;
  final Value<bool> archived;
  final Value<int> rowid;
  const ListsCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.device = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.sheetRow = const Value.absent(),
    this.syncedHash = const Value.absent(),
    this.baseSnapshot = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.folderId = const Value.absent(),
    this.color = const Value.absent(),
    this.kind = const Value.absent(),
    this.view = const Value.absent(),
    this.groupBy = const Value.absent(),
    this.orderBy = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isInbox = const Value.absent(),
    this.muted = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListsCompanion.insert({
    required String createdAt,
    required String updatedAt,
    this.version = const Value.absent(),
    this.device = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.sheetRow = const Value.absent(),
    this.syncedHash = const Value.absent(),
    this.baseSnapshot = const Value.absent(),
    required String id,
    this.name = const Value.absent(),
    this.folderId = const Value.absent(),
    this.color = const Value.absent(),
    this.kind = const Value.absent(),
    this.view = const Value.absent(),
    this.groupBy = const Value.absent(),
    this.orderBy = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isInbox = const Value.absent(),
    this.muted = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       id = Value(id);
  static Insertable<TaskList> custom({
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? version,
    Expression<String>? device,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? sheetRow,
    Expression<String>? syncedHash,
    Expression<String>? baseSnapshot,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? folderId,
    Expression<String>? color,
    Expression<String>? kind,
    Expression<String>? view,
    Expression<String>? groupBy,
    Expression<String>? orderBy,
    Expression<double>? sortOrder,
    Expression<bool>? isInbox,
    Expression<bool>? muted,
    Expression<bool>? archived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (device != null) 'device': device,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (sheetRow != null) 'sheet_row': sheetRow,
      if (syncedHash != null) 'synced_hash': syncedHash,
      if (baseSnapshot != null) 'base_snapshot': baseSnapshot,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (folderId != null) 'folder_id': folderId,
      if (color != null) 'color': color,
      if (kind != null) 'kind': kind,
      if (view != null) 'view': view,
      if (groupBy != null) 'group_by': groupBy,
      if (orderBy != null) 'order_by': orderBy,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isInbox != null) 'is_inbox': isInbox,
      if (muted != null) 'muted': muted,
      if (archived != null) 'archived': archived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListsCompanion copyWith({
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? version,
    Value<String>? device,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<int?>? sheetRow,
    Value<String?>? syncedHash,
    Value<String?>? baseSnapshot,
    Value<String>? id,
    Value<String>? name,
    Value<String?>? folderId,
    Value<String?>? color,
    Value<String>? kind,
    Value<String>? view,
    Value<String?>? groupBy,
    Value<String?>? orderBy,
    Value<double>? sortOrder,
    Value<bool>? isInbox,
    Value<bool>? muted,
    Value<bool>? archived,
    Value<int>? rowid,
  }) {
    return ListsCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      device: device ?? this.device,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      sheetRow: sheetRow ?? this.sheetRow,
      syncedHash: syncedHash ?? this.syncedHash,
      baseSnapshot: baseSnapshot ?? this.baseSnapshot,
      id: id ?? this.id,
      name: name ?? this.name,
      folderId: folderId ?? this.folderId,
      color: color ?? this.color,
      kind: kind ?? this.kind,
      view: view ?? this.view,
      groupBy: groupBy ?? this.groupBy,
      orderBy: orderBy ?? this.orderBy,
      sortOrder: sortOrder ?? this.sortOrder,
      isInbox: isInbox ?? this.isInbox,
      muted: muted ?? this.muted,
      archived: archived ?? this.archived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (device.present) {
      map['device'] = Variable<String>(device.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (sheetRow.present) {
      map['sheet_row'] = Variable<int>(sheetRow.value);
    }
    if (syncedHash.present) {
      map['synced_hash'] = Variable<String>(syncedHash.value);
    }
    if (baseSnapshot.present) {
      map['base_snapshot'] = Variable<String>(baseSnapshot.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (view.present) {
      map['view'] = Variable<String>(view.value);
    }
    if (groupBy.present) {
      map['group_by'] = Variable<String>(groupBy.value);
    }
    if (orderBy.present) {
      map['order_by'] = Variable<String>(orderBy.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (isInbox.present) {
      map['is_inbox'] = Variable<bool>(isInbox.value);
    }
    if (muted.present) {
      map['muted'] = Variable<bool>(muted.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListsCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('device: $device, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('sheetRow: $sheetRow, ')
          ..write('syncedHash: $syncedHash, ')
          ..write('baseSnapshot: $baseSnapshot, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('folderId: $folderId, ')
          ..write('color: $color, ')
          ..write('kind: $kind, ')
          ..write('view: $view, ')
          ..write('groupBy: $groupBy, ')
          ..write('orderBy: $orderBy, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isInbox: $isInbox, ')
          ..write('muted: $muted, ')
          ..write('archived: $archived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaEntry extends DataClass implements Insertable<MetaEntry> {
  final String key;
  final String value;
  const MetaEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaEntry copyWith({String? key, String? value}) =>
      MetaEntry(key: key ?? this.key, value: value ?? this.value);
  MetaEntry copyWithCompanion(MetaCompanion data) {
    return MetaEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<MetaEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeviceStateTable extends DeviceState
    with TableInfo<$DeviceStateTable, DeviceStateEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceStateEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DeviceStateEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceStateEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $DeviceStateTable createAlias(String alias) {
    return $DeviceStateTable(attachedDatabase, alias);
  }
}

class DeviceStateEntry extends DataClass
    implements Insertable<DeviceStateEntry> {
  final String key;
  final String value;
  const DeviceStateEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  DeviceStateCompanion toCompanion(bool nullToAbsent) {
    return DeviceStateCompanion(key: Value(key), value: Value(value));
  }

  factory DeviceStateEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceStateEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  DeviceStateEntry copyWith({String? key, String? value}) =>
      DeviceStateEntry(key: key ?? this.key, value: value ?? this.value);
  DeviceStateEntry copyWithCompanion(DeviceStateCompanion data) {
    return DeviceStateEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceStateEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceStateEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class DeviceStateCompanion extends UpdateCompanion<DeviceStateEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const DeviceStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceStateCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<DeviceStateEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceStateCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return DeviceStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $ListsTable lists = $ListsTable(this);
  late final $MetaTable meta = $MetaTable(this);
  late final $DeviceStateTable deviceState = $DeviceStateTable(this);
  late final Index tasksListIdx = Index(
    'tasks_list_idx',
    'CREATE INDEX tasks_list_idx ON tasks (list_id)',
  );
  late final Index tasksParentIdx = Index(
    'tasks_parent_idx',
    'CREATE INDEX tasks_parent_idx ON tasks (parent_id)',
  );
  late final Index tasksDirtyIdx = Index(
    'tasks_dirty_idx',
    'CREATE INDEX tasks_dirty_idx ON tasks (dirty)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tasks,
    lists,
    meta,
    deviceState,
    tasksListIdx,
    tasksParentIdx,
    tasksDirtyIdx,
  ];
}

typedef $$TasksTableCreateCompanionBuilder = TasksCompanion Function({
  required String createdAt,
  required String updatedAt,
  Value<int> version,
  Value<String> device,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> sheetRow,
  Value<String?> syncedHash,
  Value<String?> baseSnapshot,
  required String id,
  Value<String?> listId,
  Value<String?> parentId,
  Value<String?> sectionId,
  Value<String> kind,
  Value<String> title,
  Value<String> content,
  Value<int> priority,
  Value<int> status,
  Value<String?> startAt,
  Value<String?> dueAt,
  Value<bool> allDay,
  Value<int?> durationMin,
  Value<String?> tz,
  Value<String?> rrule,
  Value<String> repeatFrom,
  Value<String?> exDates,
  Value<String?> reminders,
  Value<bool> constantAlert,
  Value<String> tags,
  Value<double> sortOrder,
  Value<String?> pinnedAt,
  Value<String?> completedAt,
  Value<int> rowid,
});
typedef $$TasksTableUpdateCompanionBuilder = TasksCompanion Function({
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<int> version,
  Value<String> device,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> sheetRow,
  Value<String?> syncedHash,
  Value<String?> baseSnapshot,
  Value<String> id,
  Value<String?> listId,
  Value<String?> parentId,
  Value<String?> sectionId,
  Value<String> kind,
  Value<String> title,
  Value<String> content,
  Value<int> priority,
  Value<int> status,
  Value<String?> startAt,
  Value<String?> dueAt,
  Value<bool> allDay,
  Value<int?> durationMin,
  Value<String?> tz,
  Value<String?> rrule,
  Value<String> repeatFrom,
  Value<String?> exDates,
  Value<String?> reminders,
  Value<bool> constantAlert,
  Value<String> tags,
  Value<double> sortOrder,
  Value<String?> pinnedAt,
  Value<String?> completedAt,
  Value<int> rowid,
});

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get device => $composableBuilder(
    column: $table.device,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sheetRow => $composableBuilder(
    column: $table.sheetRow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncedHash => $composableBuilder(
    column: $table.syncedHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseSnapshot => $composableBuilder(
    column: $table.baseSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rrule => $composableBuilder(
    column: $table.rrule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatFrom => $composableBuilder(
    column: $table.repeatFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exDates => $composableBuilder(
    column: $table.exDates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminders => $composableBuilder(
    column: $table.reminders,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get constantAlert => $composableBuilder(
    column: $table.constantAlert,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get device => $composableBuilder(
    column: $table.device,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sheetRow => $composableBuilder(
    column: $table.sheetRow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncedHash => $composableBuilder(
    column: $table.syncedHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseSnapshot => $composableBuilder(
    column: $table.baseSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rrule => $composableBuilder(
    column: $table.rrule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatFrom => $composableBuilder(
    column: $table.repeatFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exDates => $composableBuilder(
    column: $table.exDates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminders => $composableBuilder(
    column: $table.reminders,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get constantAlert => $composableBuilder(
    column: $table.constantAlert,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get device =>
      $composableBuilder(column: $table.device, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get sheetRow =>
      $composableBuilder(column: $table.sheetRow, builder: (column) => column);

  GeneratedColumn<String> get syncedHash => $composableBuilder(
    column: $table.syncedHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseSnapshot => $composableBuilder(
    column: $table.baseSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<String> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tz =>
      $composableBuilder(column: $table.tz, builder: (column) => column);

  GeneratedColumn<String> get rrule =>
      $composableBuilder(column: $table.rrule, builder: (column) => column);

  GeneratedColumn<String> get repeatFrom => $composableBuilder(
    column: $table.repeatFrom,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exDates =>
      $composableBuilder(column: $table.exDates, builder: (column) => column);

  GeneratedColumn<String> get reminders =>
      $composableBuilder(column: $table.reminders, builder: (column) => column);

  GeneratedColumn<bool> get constantAlert => $composableBuilder(
    column: $table.constantAlert,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get pinnedAt =>
      $composableBuilder(column: $table.pinnedAt, builder: (column) => column);

  GeneratedColumn<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          Task,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
          Task,
          PrefetchHooks Function()
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> device = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int?> sheetRow = const Value.absent(),
                Value<String?> syncedHash = const Value.absent(),
                Value<String?> baseSnapshot = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> listId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<String?> startAt = const Value.absent(),
                Value<String?> dueAt = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<int?> durationMin = const Value.absent(),
                Value<String?> tz = const Value.absent(),
                Value<String?> rrule = const Value.absent(),
                Value<String> repeatFrom = const Value.absent(),
                Value<String?> exDates = const Value.absent(),
                Value<String?> reminders = const Value.absent(),
                Value<bool> constantAlert = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<String?> pinnedAt = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                device: device,
                deleted: deleted,
                dirty: dirty,
                sheetRow: sheetRow,
                syncedHash: syncedHash,
                baseSnapshot: baseSnapshot,
                id: id,
                listId: listId,
                parentId: parentId,
                sectionId: sectionId,
                kind: kind,
                title: title,
                content: content,
                priority: priority,
                status: status,
                startAt: startAt,
                dueAt: dueAt,
                allDay: allDay,
                durationMin: durationMin,
                tz: tz,
                rrule: rrule,
                repeatFrom: repeatFrom,
                exDates: exDates,
                reminders: reminders,
                constantAlert: constantAlert,
                tags: tags,
                sortOrder: sortOrder,
                pinnedAt: pinnedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String createdAt,
                required String updatedAt,
                Value<int> version = const Value.absent(),
                Value<String> device = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int?> sheetRow = const Value.absent(),
                Value<String?> syncedHash = const Value.absent(),
                Value<String?> baseSnapshot = const Value.absent(),
                required String id,
                Value<String?> listId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<String?> startAt = const Value.absent(),
                Value<String?> dueAt = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<int?> durationMin = const Value.absent(),
                Value<String?> tz = const Value.absent(),
                Value<String?> rrule = const Value.absent(),
                Value<String> repeatFrom = const Value.absent(),
                Value<String?> exDates = const Value.absent(),
                Value<String?> reminders = const Value.absent(),
                Value<bool> constantAlert = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<String?> pinnedAt = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                device: device,
                deleted: deleted,
                dirty: dirty,
                sheetRow: sheetRow,
                syncedHash: syncedHash,
                baseSnapshot: baseSnapshot,
                id: id,
                listId: listId,
                parentId: parentId,
                sectionId: sectionId,
                kind: kind,
                title: title,
                content: content,
                priority: priority,
                status: status,
                startAt: startAt,
                dueAt: dueAt,
                allDay: allDay,
                durationMin: durationMin,
                tz: tz,
                rrule: rrule,
                repeatFrom: repeatFrom,
                exDates: exDates,
                reminders: reminders,
                constantAlert: constantAlert,
                tags: tags,
                sortOrder: sortOrder,
                pinnedAt: pinnedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TasksTable, Task>(table),
                  BaseReferences<_$AppDatabase, $TasksTable, Task>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      Task,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
      Task,
      PrefetchHooks Function()
    >;
typedef $$ListsTableCreateCompanionBuilder = ListsCompanion Function({
  required String createdAt,
  required String updatedAt,
  Value<int> version,
  Value<String> device,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> sheetRow,
  Value<String?> syncedHash,
  Value<String?> baseSnapshot,
  required String id,
  Value<String> name,
  Value<String?> folderId,
  Value<String?> color,
  Value<String> kind,
  Value<String> view,
  Value<String?> groupBy,
  Value<String?> orderBy,
  Value<double> sortOrder,
  Value<bool> isInbox,
  Value<bool> muted,
  Value<bool> archived,
  Value<int> rowid,
});
typedef $$ListsTableUpdateCompanionBuilder = ListsCompanion Function({
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<int> version,
  Value<String> device,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> sheetRow,
  Value<String?> syncedHash,
  Value<String?> baseSnapshot,
  Value<String> id,
  Value<String> name,
  Value<String?> folderId,
  Value<String?> color,
  Value<String> kind,
  Value<String> view,
  Value<String?> groupBy,
  Value<String?> orderBy,
  Value<double> sortOrder,
  Value<bool> isInbox,
  Value<bool> muted,
  Value<bool> archived,
  Value<int> rowid,
});

class $$ListsTableFilterComposer extends Composer<_$AppDatabase, $ListsTable> {
  $$ListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get device => $composableBuilder(
    column: $table.device,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sheetRow => $composableBuilder(
    column: $table.sheetRow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncedHash => $composableBuilder(
    column: $table.syncedHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseSnapshot => $composableBuilder(
    column: $table.baseSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get view => $composableBuilder(
    column: $table.view,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupBy => $composableBuilder(
    column: $table.groupBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderBy => $composableBuilder(
    column: $table.orderBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isInbox => $composableBuilder(
    column: $table.isInbox,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get muted => $composableBuilder(
    column: $table.muted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ListsTableOrderingComposer
    extends Composer<_$AppDatabase, $ListsTable> {
  $$ListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get device => $composableBuilder(
    column: $table.device,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sheetRow => $composableBuilder(
    column: $table.sheetRow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncedHash => $composableBuilder(
    column: $table.syncedHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseSnapshot => $composableBuilder(
    column: $table.baseSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get view => $composableBuilder(
    column: $table.view,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupBy => $composableBuilder(
    column: $table.groupBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderBy => $composableBuilder(
    column: $table.orderBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isInbox => $composableBuilder(
    column: $table.isInbox,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get muted => $composableBuilder(
    column: $table.muted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ListsTable> {
  $$ListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get device =>
      $composableBuilder(column: $table.device, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get sheetRow =>
      $composableBuilder(column: $table.sheetRow, builder: (column) => column);

  GeneratedColumn<String> get syncedHash => $composableBuilder(
    column: $table.syncedHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseSnapshot => $composableBuilder(
    column: $table.baseSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get view =>
      $composableBuilder(column: $table.view, builder: (column) => column);

  GeneratedColumn<String> get groupBy =>
      $composableBuilder(column: $table.groupBy, builder: (column) => column);

  GeneratedColumn<String> get orderBy =>
      $composableBuilder(column: $table.orderBy, builder: (column) => column);

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isInbox =>
      $composableBuilder(column: $table.isInbox, builder: (column) => column);

  GeneratedColumn<bool> get muted =>
      $composableBuilder(column: $table.muted, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);
}

class $$ListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ListsTable,
          TaskList,
          $$ListsTableFilterComposer,
          $$ListsTableOrderingComposer,
          $$ListsTableAnnotationComposer,
          $$ListsTableCreateCompanionBuilder,
          $$ListsTableUpdateCompanionBuilder,
          (TaskList, BaseReferences<_$AppDatabase, $ListsTable, TaskList>),
          TaskList,
          PrefetchHooks Function()
        > {
  $$ListsTableTableManager(_$AppDatabase db, $ListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> device = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int?> sheetRow = const Value.absent(),
                Value<String?> syncedHash = const Value.absent(),
                Value<String?> baseSnapshot = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> view = const Value.absent(),
                Value<String?> groupBy = const Value.absent(),
                Value<String?> orderBy = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<bool> isInbox = const Value.absent(),
                Value<bool> muted = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListsCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                device: device,
                deleted: deleted,
                dirty: dirty,
                sheetRow: sheetRow,
                syncedHash: syncedHash,
                baseSnapshot: baseSnapshot,
                id: id,
                name: name,
                folderId: folderId,
                color: color,
                kind: kind,
                view: view,
                groupBy: groupBy,
                orderBy: orderBy,
                sortOrder: sortOrder,
                isInbox: isInbox,
                muted: muted,
                archived: archived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String createdAt,
                required String updatedAt,
                Value<int> version = const Value.absent(),
                Value<String> device = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int?> sheetRow = const Value.absent(),
                Value<String?> syncedHash = const Value.absent(),
                Value<String?> baseSnapshot = const Value.absent(),
                required String id,
                Value<String> name = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> view = const Value.absent(),
                Value<String?> groupBy = const Value.absent(),
                Value<String?> orderBy = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<bool> isInbox = const Value.absent(),
                Value<bool> muted = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListsCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                device: device,
                deleted: deleted,
                dirty: dirty,
                sheetRow: sheetRow,
                syncedHash: syncedHash,
                baseSnapshot: baseSnapshot,
                id: id,
                name: name,
                folderId: folderId,
                color: color,
                kind: kind,
                view: view,
                groupBy: groupBy,
                orderBy: orderBy,
                sortOrder: sortOrder,
                isInbox: isInbox,
                muted: muted,
                archived: archived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ListsTable, TaskList>(table),
                  BaseReferences<_$AppDatabase, $ListsTable, TaskList>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ListsTable,
      TaskList,
      $$ListsTableFilterComposer,
      $$ListsTableOrderingComposer,
      $$ListsTableAnnotationComposer,
      $$ListsTableCreateCompanionBuilder,
      $$ListsTableUpdateCompanionBuilder,
      (TaskList, BaseReferences<_$AppDatabase, $ListsTable, TaskList>),
      TaskList,
      PrefetchHooks Function()
    >;
typedef $$MetaTableCreateCompanionBuilder = MetaCompanion Function({
  required String key,
  Value<String> value,
  Value<int> rowid,
});
typedef $$MetaTableUpdateCompanionBuilder = MetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$MetaTableFilterComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaTableOrderingComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaTable,
          MetaEntry,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaEntry, BaseReferences<_$AppDatabase, $MetaTable, MetaEntry>),
          MetaEntry,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$AppDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MetaTable, MetaEntry>(table),
                  BaseReferences<_$AppDatabase, $MetaTable, MetaEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaTable,
      MetaEntry,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaEntry, BaseReferences<_$AppDatabase, $MetaTable, MetaEntry>),
      MetaEntry,
      PrefetchHooks Function()
    >;
typedef $$DeviceStateTableCreateCompanionBuilder =
    DeviceStateCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$DeviceStateTableUpdateCompanionBuilder =
    DeviceStateCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$DeviceStateTableFilterComposer
    extends Composer<_$AppDatabase, $DeviceStateTable> {
  $$DeviceStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceStateTableOrderingComposer
    extends Composer<_$AppDatabase, $DeviceStateTable> {
  $$DeviceStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeviceStateTable> {
  $$DeviceStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$DeviceStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeviceStateTable,
          DeviceStateEntry,
          $$DeviceStateTableFilterComposer,
          $$DeviceStateTableOrderingComposer,
          $$DeviceStateTableAnnotationComposer,
          $$DeviceStateTableCreateCompanionBuilder,
          $$DeviceStateTableUpdateCompanionBuilder,
          (
            DeviceStateEntry,
            BaseReferences<_$AppDatabase, $DeviceStateTable, DeviceStateEntry>,
          ),
          DeviceStateEntry,
          PrefetchHooks Function()
        > {
  $$DeviceStateTableTableManager(_$AppDatabase db, $DeviceStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => DeviceStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => DeviceStateCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DeviceStateTable, DeviceStateEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DeviceStateTable,
                    DeviceStateEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeviceStateTable,
      DeviceStateEntry,
      $$DeviceStateTableFilterComposer,
      $$DeviceStateTableOrderingComposer,
      $$DeviceStateTableAnnotationComposer,
      $$DeviceStateTableCreateCompanionBuilder,
      $$DeviceStateTableUpdateCompanionBuilder,
      (
        DeviceStateEntry,
        BaseReferences<_$AppDatabase, $DeviceStateTable, DeviceStateEntry>,
      ),
      DeviceStateEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$ListsTableTableManager get lists =>
      $$ListsTableTableManager(_db, _db.lists);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
  $$DeviceStateTableTableManager get deviceState =>
      $$DeviceStateTableTableManager(_db, _db.deviceState);
}
