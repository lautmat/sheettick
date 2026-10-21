# Prompt: start phase 1

Open a new Claude Code session in the SheetTick repo root and paste everything between the lines.

---

We're starting **phase 1 (Daily driver)** of SheetTick: a personal TickTick-style task app for Windows and Android
(Flutter), with local SQLite on each device synced to my own Google Sheet. Phase 0 is finished and merged to `main`:
sign-in on both platforms, Sheet bootstrap, the sync engine with its conflict tests, a minimal Inbox UI and CI. It was
verified on real devices (Windows app + my Samsung phone, one Google Workspace account).

**Read first, in this order:** `CLAUDE.md`, `docs/roadmap.md` (the P1 section), `docs/architecture.md`,
`docs/sheet-schema.md`, `docs/sync-protocol.md`, `docs/dev-setup.md`, `app/secrets/README.md`, then skim
`app/lib/core/` (`sheets/`, `sync/`, `auth/`, `db/`) and `app/test/support/`.

## State of the code
- `core/sheets`: `SheetsBackend` interface, `GoogleSheetsBackend`, `SheetBootstrap`, `sheet_schema.dart` (all 15 tabs as
  data, tested against the doc). `core/sync`: `SyncEngine` (pull, three-way merge, push), `LocalWriter` (use it for every
  local write), `DriftLocalStore`, `SyncController`. `core/auth`: Windows loopback OAuth + Android Google Sign-In.
- The drift schema and the sync engine currently cover **only `tasks` and `lists`**. The other tabs exist in the Sheet
  and in `sheet_schema.dart` but have no local tables yet, and `SyncEngine` is built for `tabs: ['tasks', 'lists']`.
- Tests: `flutter test` (~170) with `FakeSheetsBackend`, `TestDevice` (a simulated install with its own clock and
  database) and `HookedBackend` in `app/test/support/`. A test parses `docs/sheet-schema.md` and fails if code and doc
  diverge, so keep the doc, the drift tables, `sheet_schema.dart` and `meta.schema_version` in step (CLAUDE.md rule).
- Not built yet: reminders/notifications, background sync on Android (WorkManager), tray/hotkey on Windows, the
  `View` tab is formula-only, Android release signing (P3).

## How to run things
- Windows: `cd app; flutter run -d windows --dart-define-from-file=secrets/dart_defines.json`
- Android: debug build with `--dart-define-from-file=secrets/dart_defines_android.json` (Web client id only, no desktop
  secret), install with `adb install -r`. My phone is a Samsung (`adb devices` to see it); its screensaver can steal
  focus, so wake it before screenshots. USB debugging is already set up.
- `app/secrets/` is git-ignored and already filled in (OAuth client files). **Never print, commit or paste its contents.**
  Google no longer shows a client secret after creation; if one is lost, add a new one and delete the old.
- Local databases: Windows `%USERPROFILE%\Documents\sheettick.sqlite`; phone via
  `adb exec-out run-as com.lmathieu.sheettick cat app_flutter/sheettick.sqlite`. Read them with Python's `sqlite3`
  (`mode=ro`). The spreadsheet id is in the `device_state` table. The Sheet holds only my test tasks: edit or delete
  them freely, but ask before doing anything destructive to the spreadsheet.
- Toolchain is in `docs/dev-setup.md` (Flutter at `C:\dev\flutter`, JDK 21, NDK 28.2). `flutter doctor` is clean.

## Lessons from phase 0 (please apply them)
1. **Don't stack PRs.** I stacked seven and had to merge each branch upward after every review fix. Make one small PR
   per issue off `main` and merge it (with me) before starting the next. If you ever must stack, merge with merge
   commits, never squash.
2. Writes through the Sheets API **clear a cell's plain-text format**; the backend re-applies it after every write. Any
   new tab or write path must go through `GoogleSheetsBackend` so that keeps working. Dates in the Sheet are text; a
   Sheets date serial is decoded defensively.
3. Real Google behaviour differs from fakes. For anything that touches the Sheets/Drive API, verify once against the real
   Sheet (I can approve sign-in on my devices) and not only against the fake. If a Sheets connector is available in
   the session it can read the real spreadsheet to check results; a Drive connector cannot see app-created files
   (`drive.file`).
4. Being offline is normal, not an error: the UI shows a calm "Offline" note. Keep rows dirty until the Sheet accepts
   them; never drop local changes.
5. Windows tooling: in PowerShell 5.1 write commit messages with `[IO.File]::WriteAllText` (UTF-8 **without BOM**) and
   `git commit -F`; double quotes inside `-m` break. In Git Bash a `/` inside a quoted string can be turned into a path.
   Widget tests with drift streams need `await tester.pump(const Duration(milliseconds: 1))` after unmounting.
6. For Google Cloud console work, use Claude in Chrome (my real Chrome is signed in); the built-in browser kept
   getting signed out. Never accept terms or cookie banners for me without asking.
7. Automated reviewers comment on PRs. Fix what is valid, say why when you decline, reply on the thread and resolve it.

## Do this
1. Break the **P1** section of `docs/roadmap.md` into GitHub issues in the milestone "P1 Daily driver" (the milestone
   exists and is empty). Small, independently shippable issues, each with a "Done when". Suggested order: local tables
   and sync for the remaining tabs (folders, sections, checklist, tags) first, since everything else builds on them;
   then lists/folders/sections UI, subtasks and checklists, tags and priority, dates and reminders (notifications on both
   platforms), RRULE recurrence, quick-add parsing (English + French), smart lists, search/sort/group, undo,
   drag and drop, theme, and the one-time TickTick import. **Show me the list and wait for my OK before coding.**
2. Then work through them in order: one branch and one PR per issue, closing the issue from the PR, conventional
   commits, `flutter analyze` and `flutter test` before every commit, and a one-line status after each issue.
3. If a decision changes the schema, the sync rules or the stack, stop and ask me instead of improvising.
4. After each user-visible feature, say what you verified yourself and what I need to check on the phone.

---

Notes for whoever starts it:
- Pick the model in the Claude app's model picker; a prompt cannot set it.
- Phase 0 exit check and its results are recorded on issue #10.
