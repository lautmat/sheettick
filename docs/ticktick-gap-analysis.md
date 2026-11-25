# SheetTick against TickTick: gap analysis and recommendations

Written 2026-11-24, after batch edit and touch drag-and-drop landed on the phone. Sources: `docs/roadmap.md`, the open
GitHub issues, `docs/sheet-schema.md`, the Android manifest and the code under `app/lib`. The TickTick side is its
feature set as the Windows and Android apps ship it (see `docs/research/rea-findings.md` for what was reverse
engineered); it was not re-checked against a live TickTick account for this note.

Updated 2026-11-25: batch edit (PR #109) and swipe actions (#69, PR #117) merged; every recommendation now has an issue.

Legend: **Done** · **Partial** (works, with a named hole) · **Planned** (has an issue or a roadmap line) ·
**Not planned** (in TickTick, nowhere in the roadmap).

The owner's real data, from the 2026-11-11 audit, decides what matters: 87 open tasks, 46 of them with no date,
nothing left overdue (so rescheduling is constant), one task with a reminder, eight time zones, and no habits,
countdowns, focus sessions or connected calendars.

## 1. Tasks and capture

| TickTick feature | State | Note |
| --- | --- | --- |
| Title, Markdown notes, checklist items | Done | |
| Subtasks, indent and outdent | Done | Parent progress and fold: #72 |
| Priority (4 levels), tags | Done | Tag colour, rename, nesting: #77 |
| Quick-add with natural-language parsing | Done | English and French; shows a preview |
| Quick-add with buttons (date, priority, list, tag) | Planned | #111. Phone typing is slow; see recommendation 4 |
| Duplicate a task | Planned | #71 |
| Pin to the top | Planned | #74 |
| Task defaults (list, date, reminder) | Planned | #70; new tasks already default to today |
| Won't Do | Done | |
| Task templates | Planned | P3 |
| Attachments (images, files) | Planned | P3, through Drive |
| Comments / activity log on a task | **Not planned** | Single user: low value |
| Note-type tasks (`kind = NOTE`) | Partial | In the schema, no UI |
| Convert a task to a subtask or back by drag | **Not planned** | Indent and Outdent in the menu do it |
| Merge tasks, copy link to a task, share as text | **Not planned** | |
| Capture from anywhere (share sheet, select-text action) | Planned | #120 (share target, select-text) and #68 (capture tab). The manifest has no `SEND` intent filter yet |
| Capture by email, Telegram, voice notes | Not planned / later | The `capture` tab (#68) covers the simple cases |

## 2. Dates, reminders, repeat

| TickTick feature | State | Note |
| --- | --- | --- |
| Start and due, all-day or timed, time zones | Done | Travel tests (#64) |
| Duration and time range | Planned | #78 |
| Reminders (several, relative, custom) | Done | #27, #97 |
| Snooze | Done | #28 |
| Complete or postpone **from the notification** | Planned | #113. Only Snooze is offered. See recommendation 7 |
| Daily summary / alert | Planned | #67 |
| Persistent and full-screen reminders | Planned | P3; one open task in 87 has a reminder |
| Location reminders | Later | |
| Repeat: RRULE, custom, from due or from completion | Done | #29, #61 |
| Skip one occurrence | Done | #62 |
| Streak and history of a repeating task | Planned | #73 |
| Lunar, legal-holiday and Ebbinghaus repeats | **Not planned** | Not needed |
| Postpone in one step | Done | #66 |
| **Postpone or "move to Today" for many tasks at once** | **Done (PR #109)** | Selection bar: Today, Tomorrow, Next week, No date |
| Pick any date for many tasks at once | **Done (#110)** | More > Pick a date…; times of day are kept |

## 3. Organising

| TickTick feature | State | Note |
| --- | --- | --- |
| Folders, lists, sections | Done | #20, #21 |
| List colour and icon | Partial | Colour picker in the sidebar; no icon yet |
| Archive a list | Partial | Hidden from smart lists; no "unarchive" screen checked |
| Smart lists: Today, Tomorrow, Next 7 Days, All, No Date, Completed, Won't Do, Trash | Done | #32, #65 |
| Show, hide and reorder smart lists | **Not planned** | |
| Custom filters (saved queries) | Planned | P2. `filters` tab exists in the schema |
| Search | Partial | Titles and notes (FTS5); checklist items and filters: #75 |
| Sort and group | Done | #34. Sort by modified date and tag: #76 |
| Tag view in the sidebar | Planned | #77 |
| Share a list, assign a task | Not planned | Single user |

## 4. Views

| TickTick view | State |
| --- | --- |
| List | Done |
| Eisenhower matrix | Planned (P2) |
| Kanban | Planned (P2); `lists.view` is in the schema |
| Calendar: day, week, month | Planned (P2) |
| Timeline | Planned (P3) |
| Year heatmap | Planned (P3) |
| Google Calendar overlay, iCal subscriptions | Later |
| Plan Your Day | Later |

## 5. Selecting, moving and reordering

| TickTick behaviour | State | Note |
| --- | --- | --- |
| Long press to start selecting | **Done (PR #109)** | Hold, then lift: select. Hold, then move: drag |
| Select all | **Done (PR #109)** | Leaves out tasks in a folded section |
| Bulk complete, date, move to list, priority, trash | **Done (PR #109)** | One Undo for the whole batch |
| Bulk tag | **Done (#110)** | More > Add tag…: type a name or tap an existing tag; one Undo, which also removes a tag the change made |
| Bulk pin, bulk duplicate | Not planned | Pin (#74) and Duplicate (#71) come first |
| Drag to reorder, or into a section | Done (#36) | |
| Drag scrolls the list at the edges | **Done (PR #109)** | It did not before; on a phone a drag could not leave the first screen |
| Drag onto a list in the sidebar | Done on wide screens | On a phone the sidebar is a drawer: use Move |
| Drag onto Today or Tomorrow in the sidebar | Planned | #125. One line of work on the desktop, since lists already take drops |
| Drag in smart lists | Not applicable | They are sorted by date, so there is no manual order |
| Swipe a row to complete, postpone, move or trash | **Done (#69, PR #117)** | Right completes or reopens; left offers dates, Move and Trash. Touch screens only |

## 6. Android

| Feature | State | Note |
| --- | --- | --- |
| Background sync (WorkManager) | Done, **unchecked on the phone** | #42 |
| Notifications survive a reboot | Done | Boot receiver in the manifest |
| Exact alarms | Done | `USE_EXACT_ALARM` |
| Home-screen widgets (list, quick-add) | Planned | #121 |
| Quick Settings tile | Planned | #121 |
| Share target / select-text action | Planned | #120 |
| Voice input | Planned | #121 |
| App lock | Planned | P3 |
| Wear OS | Later | |

## 7. Windows

| Feature | State | Note |
| --- | --- | --- |
| Tray, start with Windows, global quick-add hotkey | Done, **unchecked on the desktop** | #43 |
| Keyboard shortcuts in the app | Planned | P2, #126 |
| Sticky-note widgets | Planned | P3 |
| Single running copy | Done | #104 |
| Installer | Planned | MSIX, P3 |

## 8. Productivity modules and the rest

Habits, Pomodoro and stopwatch, focus statistics, countdowns, ambient sounds, achievements, collaboration and the AI
assistant are all in "Later". The sheet tabs for habits, focus and countdowns exist in schema v1, so nothing needs a
migration. The audit found no use of them; leave them.

## Recommendations

Ordered by the benefit to the owner's actual use, not by how long the work takes.

1. **Check #42 and #43 on real devices.** #42 (background sync) needs the phone and #43 (tray, start with Windows,
   hotkey) needs the desktop. #38 (TickTick import) is not a device check: it is blocked until the owner provides a
   TickTick export sample. These three gate the P1 exit ("TickTick no longer needed"). Everything below is polish by
   comparison, and the touch behaviour in PRs #109 and #117 has so far been tested only with widget tests, not on a phone.
   The import also decides how urgent #114 (lazy rows) and #115 (Sheet compaction) are: if it brings years of completed
   tasks, both become prerequisites.
2. ~~**Finish batch edit (#110).**~~ Done: the More menu has "Pick a date…" (a calendar for the whole selection) and
   "Add tag…". With 46 of 87 tasks undated, bulk dating was the most common job.
3. **Show more of a task in its row (#112).** Today a row shows the date and tags only. TickTick also shows checklist
   progress (2/5), the subtask count, and small icons for a reminder, a repeat and a note; in smart lists it shows the
   list name. This is what makes a long list scannable on a phone. It pairs with #72.
4. **Make adding a task possible without typing the date (#111).** A row of chips under the field (Today, Tomorrow,
   Priority, List) that edit the same text the parser reads. The parser stays the single source of truth.
5. ~~**Swipe actions (#69).**~~ Done (PR #117): right completes, left offers dates, Move and Trash, through the same helpers as
   the bar.
6. **Pin (#74), Duplicate (#71), Daily alert (#67).** Small, already specified, and each removes a daily friction.
7. **Act from the notification (#113).** Add "Complete" and "Tomorrow" buttons next to Snooze. Ship it with the daily
   alert (#67): only one open task has a reminder, so the buttons pay off mainly once the daily alert gives the owner
   a notification to act on. It is also the one item that needs work outside the app process: the action handler runs
   in a background isolate that must open the local DB, write, and reschedule reminders.
8. **Then the views:** custom filters first (they feed smart lists), then Calendar, then Kanban and Eisenhower. Do
   them in that order because the first makes the others cheaper.

### General improvements

- **Fixed while working on this: deleting a parent task from its page left its subtasks behind.** They showed up as
  top-level tasks. Both the batch "Move to Trash" and the task page now go through `trashTasks`, which takes the
  subtasks along; the page's confirmation says so when there are any.
- **Rendering cost.** `ListView(children: _rows(...))` builds a widget for every row on every change, and
  `allTasksProvider` loads every task. Fine at 87 tasks, slow at several thousand (a few years of completed tasks).
  Switch to `ListView.builder` over a flat list of row descriptors before the Completed list grows (#114).
- **Sheet growth.** Completed tasks and tombstones accumulate in the Sheet and every sync reads them. The Apps Script
  archive and compaction job is in P3; it is worth pulling forward to P2, or at least agreeing a size at which it
  becomes urgent, because a slow sync is the one failure the owner will notice (#115).
- **Accessibility of drag.** A screen reader cannot drag. Give the row custom semantics actions ("Move up", "Move
  down", "Move to list") that call the same functions as the menu (#116).
- **A sync log.** A "Last sync" screen with the last errors, in the account menu, would make the two pending device
  checks (#42, #43) quick to diagnose, so do it before them. Add a crash reporter for release builds at the same
  time (#122).
- **French interface.** The parser already understands French. If the owner works in French, localising the interface
  (ARB files) is a few hours now and a large refactor later (#123).
- **Tests that match real hardware.** Widget tests drive the drag with synthetic touches. Add one `integration_test`
  run on an Android emulator in CI for the three gestures that matter (tap, hold-and-lift, hold-and-drag), so a
  Flutter upgrade cannot change them unnoticed (#124).
- **Tracking.** Every item above now has an issue under the P2 milestone.
