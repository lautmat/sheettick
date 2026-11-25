# SheetTick

A personal, TickTick-style task manager for **Windows** and **Android** that stores every
task, list, habit and focus session as readable rows in **your own Google Sheet**.
No server to run: each device keeps a local SQLite copy and syncs with the Sheet.

> SheetTick is a working name.

## Status

**Phase 0 (foundations)** is done. The code for **phase 1 (daily driver)** is merged, and its last three issues wait
for checks on real devices. See [docs/roadmap.md](docs/roadmap.md).

## Repository layout

| Path | What it holds |
| --- | --- |
| `app/` | Flutter app (Windows + Android). |
| `apps-script/` | Optional Google Apps Script jobs (nightly archive/compaction, email reminders). Deployed with clasp. |
| `docs/` | Plan, architecture, Sheet schema, sync protocol, roadmap, decisions, research. |
| `tools/` | Helper scripts (e.g. TickTick import, REA re-analysis notes). |

## Key documents

- [docs/plan.html](docs/plan.html): the build plan as written on 2026-10-19 (open in a browser); the roadmap is the current one
- [docs/architecture.md](docs/architecture.md): how the pieces fit
- [docs/sheet-schema.md](docs/sheet-schema.md): **canonical** Google Sheet layout
- [docs/sync-protocol.md](docs/sync-protocol.md): sync algorithm and conflict rules
- [docs/roadmap.md](docs/roadmap.md): phases P0–P3 with exit criteria
- [docs/ticktick-gap-analysis.md](docs/ticktick-gap-analysis.md): what TickTick has that SheetTick lacks, and what to do next
- [docs/research/rea-findings.md](docs/research/rea-findings.md): what reverse engineering TickTick revealed
- [docs/decisions/](docs/decisions/): architecture decision records

## Stack

Flutter (Dart) · drift (SQLite + FTS5) · Google Sheets API v4 + Drive API · OAuth scope `drive.file`
