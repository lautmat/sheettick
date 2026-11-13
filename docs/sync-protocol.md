# Sync protocol

Local-first: the UI reads and writes SQLite only. The sync engine reconciles SQLite with the Sheet.
This mirrors TickTick's own design (local SQLite, per-row `etag`/`syncStatus`, batch commit, checkpoint pull),
found by reverse engineering both clients (see `research/rea-findings.md`).

## Local bookkeeping (per row, not in the Sheet)
- `dirty` (bool): changed locally since last push.
- `sheet_row` (int): cached 1-based row number in its tab.
- `synced_hash`: hash of the row's cell values as last seen in the Sheet.
- `base_snapshot`: field values at last successful sync (for field-level merge).

Per device: `last_drive_modified_time`, `last_compaction_epoch`, `device_id`.

## Triggers
App start, window/app regains focus, 3 s after the last local edit (debounced), every 2 min while open,
every 15 min in background on Android (WorkManager), manual "Sync now".

## Background sync (Android)
A periodic WorkManager job (`sheettick-background-sync`, every 15 minutes, network required, exponential backoff from
5 minutes) runs one ordinary cycle of the same `SyncEngine` in its own isolate, with no UI (`core/sync/background_sync.dart`).
It never asks the user for anything:
- It needs a token Google can give without interaction (the `drive.file` scope the account already granted in the app).
  If it cannot get one, or the device was never set up by the app, the run is skipped and counted as done.
- A network or Google error is a failed run: rows stay dirty (they are only marked synced once the Sheet has them) and
  WorkManager tries again with backoff. A deleted spreadsheet or a layout this version does not understand also skips the
  run without retrying; the app says what is wrong when it is opened.
- When the cycle changed local rows, the reminders are planned again from the database (step 6 below).
- Each run records its time and outcome in `device_state` (`last_background_sync`, not synced). The account menu shows it
  on Android ("Background sync: synced, 12 min ago"), so a job that silently skips can be seen.
- The app and the job open the same SQLite file from different isolates. A cycle that meets a busy database fails and
  is retried; nothing is lost.

## One cycle
1. **Change check.** Drive API `files.get(fields: modifiedTime)` on the spreadsheet.
   If unchanged since `last_drive_modified_time` and no local row is dirty, stop.
2. **Compaction check.** Read `meta`. If `compaction_epoch` differs from the local value, drop all `sheet_row` caches
   (row numbers changed) and do a full re-index during the pull.
3. **Pull.** One `spreadsheets.values.batchGet` for all entity tabs. For each remote row:
   - unknown `id` → insert locally;
   - remote `version` > local `version` → take remote (unless local is dirty → step 4);
   - same `version` but hash ≠ `synced_hash` → manual edit in the Sheet: take remote, treat as `version + 1`;
   - refresh `sheet_row` and `synced_hash`.
4. **Conflicts** (local dirty and remote changed): three-way merge against `base_snapshot`, field by field.
   Fields changed on one side take that side. Fields changed on both sides take the value with the newer `updated_at`.
   Result is marked dirty with `version = max(local, remote) + 1`.
5. **Push.**
   - Existing rows: one `values.batchUpdate` with a range per row. Before writing, the engine verifies the `id`
     at `sheet_row` matches (from the pull); if not, it re-indexes that tab first.
   - New rows: one `values.append` per tab (`insertDataOption=INSERT_ROWS`); parse `updates.updatedRange` to store `sheet_row`.
   - Clear `dirty`, update `synced_hash`, `base_snapshot`, `last_drive_modified_time`.
6. **Reminders.** Reschedule local notifications for every row that changed in this cycle. The app does this by planning
   reminders from the local database whenever a task row changes, so rows changed by a pull, by a local edit or by hand
   in the Sheet take the same path, and only the alarms that differ are touched. On Windows, where a scheduled toast
   cannot be cancelled outside an MSIX package, reminders are shown by the running app instead (see `core/reminders`).

## Limits and errors
- Sheets API: 60 read + 60 write requests per minute per user. A cycle uses 2–5 requests.
- HTTP 429 / 5xx: exponential backoff with jitter (1 s → 64 s), keep rows dirty.
- Auth errors: surface a "Sign in again" banner; never drop dirty rows.

## Bootstrap (first sign-in)
1. Search Drive (scope `drive.file`) for a spreadsheet created by the app; if none, create `SheetTick`.
2. Create every tab and header row from `sheet-schema.md`, write `meta.schema_version`.
3. Create the Inbox list.
4. Store the spreadsheet ID locally. A second device signs in and finds the same file.

Note: `drive.file` only sees files the app created **with the same OAuth project**. Windows and Android clients
must belong to the same Google Cloud project.

## Required tests (phase 0)
- Two simulated devices editing different fields of the same task offline → both changes survive.
- Same field on both → newer `updated_at` wins.
- Manual Sheet edit is detected and pulled.
- Row numbers shift (simulated compaction) → re-index, no wrong-row writes.
