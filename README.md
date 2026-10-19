# SheetTick

A personal, TickTick-style task manager for **Windows** and **Android** that stores every
task, list, habit and focus session as readable rows in **your own Google Sheet**.
No server to run: each device keeps a local SQLite copy and syncs with the Sheet.

> SheetTick is a working name.

## Status

Planning done, **phase 0 (foundations)** next. See [docs/roadmap.md](docs/roadmap.md).

## Repository layout

| Path | What it holds |
| --- | --- |
| `app/` | Flutter app (Windows + Android). Generated in phase 0 with `flutter create`. |
| `apps-script/` | Optional Google Apps Script jobs (nightly archive/compaction, email reminders). Deployed with clasp. |
| `docs/` | Plan, architecture, Sheet schema, sync protocol, roadmap, decisions, research. |
| `tools/` | Helper scripts (e.g. TickTick import, REA re-analysis notes). |

## Key documents

- [docs/plan.html](docs/plan.html): full build plan (open in a browser)
- [docs/architecture.md](docs/architecture.md): how the pieces fit
- [docs/sheet-schema.md](docs/sheet-schema.md): **canonical** Google Sheet layout
- [docs/sync-protocol.md](docs/sync-protocol.md): sync algorithm and conflict rules
- [docs/roadmap.md](docs/roadmap.md): phases P0–P3 with exit criteria
- [docs/research/rea-findings.md](docs/research/rea-findings.md): what reverse engineering TickTick revealed
- [docs/decisions/](docs/decisions/): architecture decision records

## Stack

Flutter (Dart) · drift (SQLite + FTS5) · Google Sheets API v4 + Drive API · OAuth scope `drive.file`
