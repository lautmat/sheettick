# Roadmap

Estimates assume one developer, part-time, working with Claude Code. Each phase is a GitHub milestone.

## P0 — Foundations (week 1)
- [x] Install Flutter (stable) with Windows desktop and Android toolchains; `flutter doctor` clean for both.
- [x] `flutter create` in `app/` (platforms: windows, android; org `com.lmathieu`).
- [x] Google Cloud project, Sheets + Drive APIs, OAuth consent screen, Desktop and Android OAuth clients.
- [x] Sign-in on both platforms with scope `drive.file`.
- [x] Sheet bootstrap: create spreadsheet, tabs and headers from `sheet-schema.md`.
- [x] drift schema for `tasks`, `lists`, `meta` (others can follow in P1).
- [x] Sync engine skeleton per `sync-protocol.md` + the four required conflict tests (fake backend).
- [x] Minimal UI: list of tasks in Inbox, add, complete, edit title.
- [x] CI: GitHub Actions running `flutter analyze` and `flutter test`.

**Exit:** a task created on Windows shows up on Android through the Sheet, and an offline edit syncs correctly.

**Status: done (2026-10-21).** Verified on Windows and an Android phone against a real Google account: sign-in, bootstrap, two-device sync, an offline edit, a hand edit in the Sheet, and staying signed in after a restart.

## P1 — Daily driver (weeks 2–5)
Lists, folders, sections, tasks, subtasks, checklists, tags, priority · dates, reminders, snooze, RRULE recurrence ·
smart date parsing in quick add · smart lists (Today, Tomorrow, Next 7 Days, All, Completed, Won't Do, Trash) ·
search, sort/group, undo, drag and drop · light/dark mode · one-time TickTick import.

**Exit:** TickTick no longer needed for everyday tasks.

## P2 — Views, focus, habits (weeks 6–9)
Calendar (day/week/month), Kanban, Eisenhower matrix, custom filters, batch edit, notes ·
Pomodoro/stopwatch + stats, habits with check-ins and streaks, constant reminder ·
Windows: tray, global quick-add hotkey, shortcuts · Android: list + quick-add widgets, QS tiles,
share target and select-text action, voice input, full-screen reminders.

**Exit:** every weekly-used TickTick feature has an equivalent.

## P3 — Polish (weeks 10–12)
Countdowns, timeline, year heatmap, templates, statistics, ambient sounds · Google Calendar overlay, Drive attachments ·
desktop sticky widgets, more Android widgets, floating focus timer · themes, app lock ·
Apps Script nightly archive/compaction · MSIX installer and signed APK.

**Exit:** installable builds kept for good.

## Later / optional
Collaboration, AI assistant, Telegram/email capture, Quick Ball overlay, voice notes + transcription,
location reminders, Wear OS, print.
