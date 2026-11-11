# Roadmap

Estimates assume one developer, part-time, working with Claude Code. Each phase is a GitHub milestone, and the
milestone's issues are the detail; this file is the overview.

Re-scoped on 2026-11-11 after an audit against the code, the GitHub issues and the owner's real TickTick data
(see "What the audit changed" at the end).

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

**Status on 2026-11-11: 18 issues merged, 3 in review or on a branch, 10 to do.**

Merged:
- [x] Sync for folders, sections, checklist and tags (#19)
- [x] Folders and lists (#20), sections (#21)
- [x] Task detail (#22), subtasks (#23), checklist items (#24), priority and tags (#25)
- [x] Start and due dates (#26), reminders (#27), snooze (#28), RRULE recurrence (#29)
- [x] Quick-add parser in English and French (#30), quick-add bar (#31)
- [x] Smart lists Today to Trash (#32), search (#33), sort and group (#34)

In review or on a branch:
- [ ] Undo (#35): PR 58 open
- [ ] Light and dark theme (#37): PR 59 open
- [ ] Drag and drop (#36): on a local branch built on the undo branch; rebase onto `main` once undo is merged

To do:
- [ ] Nightly snapshot of the spreadsheet (#63), before any real data goes in
- [ ] One-time TickTick import (#38), after #63
- [ ] Travel tests: all-day dates and repeats across time zones (#64)
- [ ] Custom repeat rule editor (#61), skip one occurrence (#62)
- [ ] No Date smart list (#65), postpone in one step (#66)
- [ ] Render Markdown in notes (#60)
- [ ] Background sync on Android with WorkManager (#42)
- [ ] Windows tray, start with Windows and global quick-add hotkey (#43)

**Exit:** TickTick no longer needed for everyday tasks.

## P2 — Views and capture (weeks 6–9)

Issues exist for the items with a number. The rest are broken into issues when the phase starts.

- Views: Eisenhower matrix, Kanban, calendar (day/week/month), custom filters, batch edit, notes.
- Everyday: daily alert (#67), task defaults (#70), duplicate (#71), pin (#74), parent progress and collapse (#72),
  streak and history on repeating tasks (#73).
- Capture: `capture` tab, so anything that can append a row creates a task (#68) · Android list and quick-add
  widgets, QS tiles, share target and select-text action, voice input, swipe actions (#69).
- Windows: keyboard shortcuts.
- Search over checklist items, with filters (#75) · sort by modified date and tag (#76).
- Low priority: tag sidebar, colour, rename and nesting (#77) · duration and time zone for timed tasks (#78).
- In the Sheet: `Stats` tab built from formulas (#79), instead of in-app statistics.
- Research: targeted REA pass on Android settings and recurrence code (#80).

**Exit:** every weekly-used TickTick feature has an equivalent.

## P3 — Polish (weeks 10–12)
Timeline, year heatmap, templates · Drive attachments · desktop sticky widgets, more Android widgets ·
constant reminder and full-screen reminders · themes, app lock ·
Apps Script nightly archive/compaction · MSIX installer and signed APK.

**Exit:** installable builds kept for good.

## Later / optional
Habits with check-ins and streaks, Pomodoro/stopwatch + stats, floating focus timer, ambient sounds, countdowns,
Google Calendar overlay, subscribed iCal calendars, Plan Your Day, in-app statistics and achievements ·
collaboration, AI assistant, Telegram/email capture (the `capture` tab covers the simple cases), Quick Ball overlay,
voice notes + transcription, location reminders, Wear OS, print.

The Sheet tabs for habits, focus, timers and countdowns stay in schema v1, so none of these needs a migration later.

## What the audit changed (2026-11-11)

- **Moved to Later:** habits, Pomodoro and focus stats, countdowns, ambient sounds, Google Calendar overlay.
  The TickTick account holds no habits, no countdowns, no connected calendars and no focus session in the last 30 days.
- **Moved to P3:** constant reminder and full-screen reminders. One open task in 87 has a reminder.
- **Moved into P1:** background sync (#42) and tray/hotkey (#43) were P2 here but already P1 in GitHub.
- **Added to P1:** features the plan promised for P1 that had no issue (#60, #61, #62), a backup before real data
  (#63), time-zone tests (#64: the tasks carry eight zones), and two things the data asks for (#65: 46 of 87 open
  tasks have no date; #66: nothing is ever left overdue, so rescheduling is constant).
- **Added to P2:** TickTick features the feature map missed (#67, #69, #70, #71, #72), plan promises with no issue
  (#74 to #78), and three additions (#68, #73, #79).
- `docs/plan.html` is the plan as written on 2026-10-19 and is not kept up to date; this file is.
