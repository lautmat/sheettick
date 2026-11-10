# Google Sheet schema (canonical)

Schema version: **1**. This file is the single source of truth for the spreadsheet layout.
Any change here must be mirrored in the drift schema, the sheet bootstrap code, and `meta.schema_version`.

One spreadsheet, created by the app on first sign-in (so it is reachable with the `drive.file` scope),
named `SheetTick`. One tab per entity. **Row 1 is the header row** with the exact column names below.
Column order in the Sheet follows this document; the app locates columns by header name, not position.

## Conventions

| Topic | Rule |
| --- | --- |
| IDs | UUID v4 strings, generated on the device that creates the row. |
| Timestamps | UTC ISO 8601 with `Z`, e.g. `2026-10-19T13:05:00Z`. |
| Dates with a time | ISO 8601 with offset, plus `tz` (IANA name) when the item has one. |
| All-day dates | `YYYY-MM-DD` and `all_day = TRUE`. |
| Booleans | `TRUE` / `FALSE` (Sheets native). |
| Lists of values | `tags`: comma-separated tag names. `reminders`, `ex_dates`, `skipped_dates`: JSON arrays. |
| Reminders | JSON array of iCal triggers relative to start/due, TickTick style: `["TRIGGER:-PT15M","TRIGGER:PT0S"]`. |
| Recurrence | RFC 5545 rule string, e.g. `RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH`. |
| Markdown | `content` and `note` fields hold Markdown. Long text is fine (Sheets cell limit: 50,000 chars). |

### Sync columns (on every entity tab, always last)

| Column | Type | Meaning |
| --- | --- | --- |
| `created_at` | timestamp | Creation time. |
| `updated_at` | timestamp | Last change, set by the writing device. |
| `version` | integer | Incremented on every change. Higher wins on pull. |
| `device` | text | Short ID of the device that wrote the row (`win-xxxx`, `and-xxxx`). |
| `deleted` | boolean | Tombstone. Rows are never removed by the app. |

## Tabs

### `tasks`
| Column | Type | Notes |
| --- | --- | --- |
| `id` | uuid | |
| `list_id` | uuid | → `lists.id`. Inbox is a list with `is_inbox = TRUE`. |
| `parent_id` | uuid | Parent task for subtasks; empty for top level. |
| `section_id` | uuid | → `sections.id` (also Kanban column). Optional. |
| `kind` | enum | `TEXT`, `CHECKLIST`, `NOTE`. |
| `title` | text | |
| `content` | markdown | Description / notes. |
| `priority` | int | `0` none, `1` low, `3` medium, `5` high (TickTick values). |
| `status` | int | `0` open, `2` completed, `-1` won't do. |
| `start_at` | datetime/date | |
| `due_at` | datetime/date | |
| `all_day` | boolean | |
| `duration_min` | int | Optional; for timed blocks. |
| `tz` | text | IANA time zone, empty = floating (follows device). |
| `rrule` | text | Recurrence rule. |
| `repeat_from` | enum | `DUE` or `COMPLETION`. |
| `ex_dates` | json | Skipped occurrences. |
| `reminders` | json | Trigger list. |
| `constant_alert` | boolean | Keep reminding until handled. |
| `tags` | text | Comma-separated tag names. |
| `sort_order` | number | Order within list/section. |
| `pinned_at` | timestamp | Empty = not pinned. |
| `completed_at` | timestamp | |
| + sync columns | | |

**Dates.** `start_at` and `due_at` share `all_day` and `tz`, so both are all-day dates or both are timed values.
An all-day task stores `YYYY-MM-DD` in each and leaves `tz` empty. A timed task stores ISO 8601 with the offset the zone
had at that moment (`2026-11-07T09:00:00+01:00`) and the IANA zone in `tz` (`Europe/Paris`); the app reads it back on the
device's own zone, so the instant is kept and the clock time follows the traveller. A timed value with an empty `tz` is
floating: it reads as the clock time written, whatever its offset. Text in either cell that is not a real date reads as
no date and is left untouched until the task's dates are edited.

**Reminders.** `reminders` is a JSON array of iCal durations, each relative to the task's start, or to its due when it
has no start (`PT0S` at the moment, `-PT15M` fifteen minutes before, `-P1D` one day before). A timed moment is the
instant above. An all-day moment is midnight at the start of the day on the device's zone, so its trigger holds the
time of day, as TickTick writes it: `PT9H` is 9:00 that day, `-PT15H` is 9:00 the day before. Whole days count on the
calendar (so "1 day before" keeps its clock time across a daylight-saving change); the rest is an exact length of time.
The app writes `TRIGGER:` before each duration and reads it with or without. Unreadable entries are ignored. Only open,
undeleted tasks have reminders.

**Recurrence.** `rrule` holds an RFC 5545 rule (`RRULE:FREQ=WEEKLY;BYDAY=MO,TH`; the `RRULE:` label is optional when
reading). A task repeats from its due, or from its start when it has no due. Finishing an open repeating task (completing
it, or marking it won't do) creates the next one as a new row: a copy with the same list, section, priority, tags, notes,
reminders, `rrule`, `repeat_from` and `ex_dates`, open, with its checklist unticked, and its start and due moved on
together. The finished task's own `rrule` is cleared, so only the live task repeats and reopening the old one starts no
second series. With `repeat_from = DUE` the next due is the next occurrence of the rule after both the task's due and
the moment it was finished, so a task finished late does not return already overdue. With `COMPLETION` the rule is
counted from the day it was finished, at the task's time of day (every 3 days means 3 days after finishing). Occurrences
on a day listed in `ex_dates` (`YYYY-MM-DD`, or an ISO date-time whose day counts) are skipped. A rule with `COUNT` counts
down in each new task's `rrule`; when none is left, or `UNTIL` has passed, no new task is created. Subtasks are not copied.

A **snooze** (remind me again in 10 minutes, an hour, tomorrow, or at a picked time) is not in the Sheet. It lives in
the device's local `device_state` table (one `reminder_snooze:<reminder>` row each), so it changes no row, no `version` and no date, and
another device still reminds at the original time. It belongs to the occurrence it was made for: when the task's dates
or the trigger move the reminder to another time, the snooze no longer applies.

### `checklist`
`id`, `task_id`, `title`, `status` (0/2), `sort_order`, `start_at`, `all_day`, `completed_at`, + sync columns.

### `lists`
`id`, `name`, `folder_id` (→ `folders.id`), `color` (hex), `kind` (`TASK`/`NOTE`), `view` (`list`/`kanban`/`timeline`),
`group_by`, `order_by`, `sort_order`, `is_inbox`, `muted`, `archived`, + sync columns.

`order_by` is how the list orders its tasks: empty is manual (the tasks' `sort_order`), else `due`, `priority`,
`created` or `title`. `group_by` is how it groups them: empty is no grouping, else `due`, `priority`, `tag` or `list`.
Both are written by the app when the user picks them in the list's Sort and group dialog, so they sync like any other
list field; an unknown value reads as the empty one. While a list is grouped its sections are not shown (the tasks keep
their `section_id`). Open tasks always come before done ones. Sorting is stable: tasks the sort cannot tell apart stay
in manual order. `due` puts the earliest due (else start) first and tasks with no date last, `priority` puts high
first, `created` puts the newest first.

### `folders`
`id`, `name`, `sort_order`, `collapsed`, + sync columns.

### `sections`
`id`, `list_id`, `name`, `sort_order`, `collapsed`, + sync columns.

### `tags`
`id`, `name` (unique), `color`, `parent` (parent tag name, for nesting), `sort_order`, + sync columns.

### `filters`
`id`, `name`, `rule_json` (AND/OR conditions over list, tag, date, priority, kind), `sort_order`, + sync columns.

### `habits`
`id`, `name`, `icon`, `color`, `section`, `type` (`BOOLEAN`/`AMOUNT`), `goal`, `step`, `unit`, `rrule`, `reminders`,
`constant_alert`, `target_days`, `target_start`, `encouragement`, `current_streak`, `max_streak`, `skipped_dates`,
`status` (0 active, 1 archived), `archived_at`, `sort_order`, + sync columns.

### `habit_checkins`
`id`, `habit_id`, `date` (`YYYY-MM-DD`), `value`, `goal`, `status` (0 none, 1 failed, 2 done), `note`, + sync columns.

### `focus`
One row per focus session.
`id`, `task_id`, `timer_id`, `type` (`POMO`/`STOPWATCH`), `start_at`, `end_at`, `pause_sec`, `status` (0 abandoned, 1 completed), `note`, + sync columns.

### `timers`
Named focus timers.
`id`, `name`, `type` (`POMO`/`STOPWATCH`), `linked_type` (`TASK`/`HABIT`/empty), `linked_id`, `pomo_minutes`, `color`, `icon`,
`status` (0 normal, 1 archived), `sort_order`, + sync columns.

### `countdowns`
`id`, `name`, `type` (`COUNTDOWN`/`ANNIVERSARY`/`BIRTHDAY`/`HOLIDAY`), `mode` (`DOWN`/`UP`), `date`, `calendar` (`SOLAR`/`LUNAR`),
`ignore_year`, `show_age`, `day_one_option` (`STANDARD`/`STANDARD_PLUS_1`), `rrule`, `reminders`, `style`, `color`, `note`,
`pinned_at`, `archived_at`, `sort_order`, + sync columns.

### `locations`
Geofence reminders (later phase; tab created from schema v1 so no migration is needed).
`id`, `task_id`, `alias`, `address`, `lat`, `lng`, `radius_m`, `trigger` (`ENTER`/`EXIT`), + sync columns.

### `attachments`
`id`, `task_id`, `drive_file_id`, `name`, `mime`, `size`, + sync columns. Files live in a Drive folder `SheetTick Attachments`.

### `meta`
Key/value tab, two columns: `key`, `value`. Keys: `schema_version`, `compaction_epoch`, `created_by_app_version`, `settings_json`.

### `View` (read-only, for humans)
Built with formulas such as
`=QUERY(tasks!A:Z, "select ... where deleted = FALSE and status = 0 order by due_at", 1)`.
The app never writes to it.

## Rules for editing the Sheet by hand
- Editing cell values in entity tabs is allowed; the app detects it on the next pull (row hash changed, same `version`).
- Do **not** sort, insert or delete rows in entity tabs. Use `View` for sorting.
- New rows typed by hand need at least `id` (any unique text) and `title`/`name`.
