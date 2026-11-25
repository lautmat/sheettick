# SheetTick: instructions for coding agents

## What this is
A personal TickTick-style task app for Windows and Android. Single user (Laurent).
The Google Sheet is the shared source of truth; each device works on a local SQLite copy.
Read `docs/architecture.md`, `docs/sheet-schema.md` and `docs/sync-protocol.md` before changing data or sync code.

## Stack and conventions
- Flutter (stable channel), Dart 3, one codebase in `app/` targeting `windows` and `android` only.
- Local DB: drift (SQLite) with FTS5 for search. State management: Riverpod.
- Google APIs: `googleapis` + `googleapis_auth`. Android sign-in via Google Sign-In; Windows via the desktop loopback OAuth flow.
- OAuth scope: `https://www.googleapis.com/auth/drive.file` only. Never request the full `spreadsheets` or `drive` scope.
- Recurrence: RFC 5545 RRULE strings (`rrule` package). Dates: ISO 8601 text in the Sheet.
- Notifications: `flutter_local_notifications` (both platforms). Background sync on Android: WorkManager.
- Keep business logic (sync, parsing, recurrence) in pure Dart under `app/lib/core/` with unit tests; UI under `app/lib/features/<feature>/`.
- Garmin watch companion: Connect IQ (Monkey C) in `garmin/`, served by the Apps Script web app in `apps-script/WebApp.js` (logic in `Today.js`, node tests). See `garmin/README.md`.

## Rules
- `docs/sheet-schema.md` is canonical. Any column change updates that doc, the drift schema, the sheet bootstrap code and `meta.schema_version` together.
- Never physically delete rows in the Sheet from the app; set `deleted = TRUE` (tombstone).
- Every write to a row bumps `version`, sets `updated_at` (UTC ISO 8601) and `device`.
- Batch Sheets API calls (one `batchGet`, one `batchUpdate`, one append per tab per sync). Back off exponentially on HTTP 429.
- Secrets never go in git: OAuth client JSON, `.env`, keystores, `.clasprc.json`. Use `app/secrets/` (git-ignored) and document required files in `app/secrets/README.md`.
- Google Apps Script in `apps-script/` deploys with clasp (`clasp create-version` then `clasp update-deployment`), never through the browser editor.
- Run `flutter analyze` and `flutter test` before committing. Conventional commit messages (`feat:`, `fix:`, `docs:`, `chore:`).
- Track work in GitHub issues under the milestone of the current phase (P0–P3).
