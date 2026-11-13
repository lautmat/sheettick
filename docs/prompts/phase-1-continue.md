# Prompt: continue phase 1 in a new session (cloud or laptop)

Paste everything between the lines into a new Claude Code session in the SheetTick repo. Written 2026-11-13; check the
open issues and pull requests first, because they are the real state and this text is not.

---

We are in the middle of **phase 1 (Daily driver)** of SheetTick: a personal TickTick-style task app for Windows and
Android (Flutter), local SQLite on each device synced to my own Google Sheet. Work from `main`.

**Read first:** `CLAUDE.md`, `docs/roadmap.md` (P1), `docs/architecture.md`, `docs/sheet-schema.md`,
`docs/sync-protocol.md`, `docs/dev-setup.md`. Then run `gh`-free checks with the GitHub tools: open issues in the
milestone "P1 Daily driver" and open pull requests.

## Where things stand
Done and merged: lists, folders, sections, subtasks, checklists, tags, priority, dates, reminders and snooze, recurrence
(custom repeat editor, skip one occurrence), quick-add parsing, smart lists (including No Date), search, sort and group,
undo, drag and drop, postpone (menus and "Postpone all overdue" in Today), Markdown notes, nightly snapshot, light and
dark theme, time-zone travel tests, background sync on Android (WorkManager), the TickTick import code.

Open, in this order:
1. **#43 Windows tray, start with Windows, global hotkey.** The pull request may still be open. It needs a Windows build
   to check (tray, Ctrl+Alt+N, the registry Run entry, hiding the window). I cannot build Windows from Linux.
2. **#88 build workflow** (manual GitHub Actions build of the APK and the Windows app). It waits on me for two things:
   check that `actions/upload-artifact` is pinned to the right commit for v4.6.2 (the SHA in the file was written from
   memory), and add the secrets listed in `docs/dev-setup.md`. After it is merged, run it once from `main` with no
   secrets to see that Android and Windows compile; the Gradle signing change in it has never been built.
3. **#38 TickTick import.** The importer and a dev-only paste dialog are merged. The data file (`ticktick-open.json`,
   88 open tasks) is in my Google Drive, not in git. The dry run was approved (all 15 repeating tasks as repeat-from-due).
   Only I can run it: build with `--dart-define=DEV_TOOLS=true`, paste, dry run, import, sync. Close #38 when I say so.
4. **#42 background sync** needs a check on my phone before the issue closes (see `docs/sync-protocol.md`, "Background
   sync (Android)"). The account menu shows the last run. If it says "skipped, Google needs you to sign in", the job could
   not get a token without a screen; the likely fix is to remember the signed-in email and ask for that account.
5. When P1 is closed, **stop and walk me through the P1 exit check** ("TickTick no longer needed for everyday tasks") on
   Windows and phone. Do not start P2.

Things I have to check by hand on a device are listed at the end of each pull request description ("To check on the
phone"). Collect them for me when I ask.

## Rules that matter (more in CLAUDE.md)
- One small branch and pull request per issue, off `main`, never stacked. Conventional commits.
- Run `flutter analyze` and `flutter test` before every commit. **Do not chain a commit after a test run with `;`** (use
  `&&`), and do not pipe `flutter test` through `grep` (it hides a hang); write the output to a file and read it.
- Ask me before schema, sync or stack changes (new packages included). Merge only when CI is green **on the current head
  commit** (check the head SHA: an event can belong to an older commit) and the bot review is answered.
- Do not run `dart format` on lib files: this project uses wide lines and it rewrites whole files.
- Never print, commit or paste anything from `app/secrets/`.
- The automated reviewer (Amazon Q) comments on every pull request. Verify each finding against the code: fix what is real
  and small, and answer on the thread (with the footer) why you decline the rest. It is wrong about as often as it is right.
- Several branches touch `pubspec.yaml`, `pubspec.lock` and `main.dart`. Merge `main` into the branch before merging it,
  keep both sides, let `flutter pub get` rebuild the lock file, rerun the tests.

## Setting up a cloud session
- Flutter is not installed. Install the pinned version (the same as CI, 3.47.7, Dart 3.13.5):
  `curl -L -o f.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.7-stable.tar.xz`
  (1.5 GB, wait for `tar xf` to finish), then put `flutter/bin` on `PATH` and
  `git config --global --add safe.directory <flutter dir>`. pub.dev works through the proxy. It warns about running as
  root; ignore it.
- Tests and CI need no secrets. A full `flutter test` takes about 2 minutes; CI about 6.
- No Android SDK and no Windows toolchain: APK and Windows builds cannot be checked here. The GitHub Actions workflow is
  how to compile them without my laptop.
- Connectors: GitHub works. TickTick, Google Drive and Sheets may or may not be connected; the TickTick connector was
  read-only for this project. My GitHub access in a session is limited to this repository: attaching another repository
  (for example to look up an action's commit) can be refused, so ask me instead of working around it.
- `app/secrets/` and the clasp login exist only on my laptop. Anything that needs them (a signed-in app run, deploying
  the Apps Script) cannot happen in the cloud.

## Why some packages are pinned where they are
- `window_manager` 0.5.2, `tray_manager` 0.5.3 and `hotkey_manager` 0.2.3 are the last plugin-style releases. Newer ones
  (0.6 and up) build a C++ library through Dart build hooks for every target including Android, and need Dart 3.14
  from 0.9 and 0.7. Do not bump them without a way to build Android.
- `launch_at_startup` cannot be used: every version that fits the SDK conflicts with the `win32` that
  `flutter_secure_storage` 11 needs. Start with Windows writes the registry `Run` value with `reg.exe` instead.
- `flutter_markdown_plus` replaces the discontinued `flutter_markdown`. `workmanager` runs the Android sync job.

---
