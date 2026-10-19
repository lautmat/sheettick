# ADR 0001: Flutter, local-first SQLite, Google Sheet as sync store

Date: 2026-10-19 · Status: accepted

## Context
Goal: TickTick-level features on Windows and Android, with all data in a Google Sheet the user owns and can read.
No existing project combines these (checked: Super Productivity, Vikunja, Tasks.org, OpenTodoList, Sheets-backed web todo apps).

## Decision
- **Build**, don't fork. Super Productivity syncs one data file, so a fork could only store an unreadable blob in Sheets.
- **Flutter** for both apps from one codebase. Considered Compose Multiplatform (TickTick's own choice for shared logic,
  but its desktop target runs on the JVM), Tauri 2 (younger Android support), .NET MAUI (smaller ecosystem).
- **Local-first**: SQLite on each device; the Sheet is the shared source of truth, synced in batches.
  Same pattern TickTick uses internally (confirmed by REA on both clients).
- **Direct Sheets API from clients** with OAuth scope `drive.file`; no server. Apps Script only for optional background jobs.

## Consequences
- Works offline and stays fast regardless of Sheets latency.
- Sync and conflict handling must be built and tested carefully (row numbers, manual edits, two offline devices).
- Reminders are scheduled per device; both devices may ring for the same task.
- Spreadsheet capacity (10 M cells) needs a yearly archive of completed tasks.
