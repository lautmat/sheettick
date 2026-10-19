# REA findings: TickTick internals

Analysis done on 2026-10-19 with [REA](https://rea.tools/) (`rea-agents` 6.7.0), static only (nothing was executed).

## Windows: TickTick.exe 4.0.8.0 (Dec 2021)
- .NET Framework 4.5.2 WPF, x64. SHA-256 `140a6937a04a2d08af9d3917a962e8619c23a3d1ece56f45222bb2eec3ffc19d`.
- 6,295 types, 32,922 methods, 187 XAML views, 52 DAOs (SQLite tables), 122 API endpoints in 25 groups, 17 themes.
- Modules (types): Calendar 41, Habit 30, Config 28, Time pickers 22, Task list 22, Pomodoro 17, Search 17, Tag 15,
  Widget 14, Print 14, Markdown editor 14, Filter 13, Detail 13, Quick add 11, Kanban 10, Lock 4, Eisenhower 3.
- Libraries: Ical.Net (RRULE), SmartDateDLL (natural-language dates), CommonMark + AvalonEdit (Markdown),
  NHunspell (spell check), NHotkey (global hotkeys), WebSocket4Net (push), sqlite3, KotlinMultiplatformAll.dll
  (business logic shared with Android via Kotlin Multiplatform).
- **Sync design**: local SQLite; each row has `etag` + `syncStatus`; `SyncService` commits dirty rows in batches
  (`/api/v2/batch/task`, `/project`, `/tag`, `/filter`, `/pomodoro`…), then pulls from a saved checkpoint;
  WebSocket `wss://wss.ticktick.com/pc` only signals "need sync".
- Model fields (REA `inspect-managed-members --type`): `TaskModel` 54 fields (projectId, parentId, priority, title,
  content, isAllDay, repeatFlag, reminders, startDate, dueDate, timeZone, isFloating, tags, sortOrder, columnId,
  exDates, repeatFrom, pinnedTime, kind, status, completedTime, etag…), `HabitModel` 27, `ProjectModel` 25,
  `PomodoroModel` 12, `HabitCheckInModel` 9, `TaskDetailItemModel` (checklist) 11, `FilterModel` 11.

## Android: com.ticktick.task 8.2.2.0 (build 8220, 26 Sep 2026)
- From the APKMirror bundle (SHA-256 `0ec607a486c29e50f0f575d6d98665875c35a3739fae720ef9ef383771e5a19d`), `base.apk` analyzed
  with REA's JADX provider (jadx-headless-mcp 0.7.1, JDK 21). Min SDK 26, target SDK 37.
- 23,285 classes (6,450 TickTick), 253 activities, 55 services, 53 receivers. Kotlin, classic Views, greenDAO, obfuscated.
- **27 widget providers**: list 4×4, scrollable, undone count, quick add, completion, today calendar, 3-day, week, grid,
  grid-week, habit (single/week/month/progress 2×2, 4×2), Pomodoro, single timer, daily focus, focus distribution
  (2×2, 4×2, 4×4), Eisenhower matrix, countdown list, single countdown, class timetable, Google Tasks large.
- Capture: 2 Quick Settings tiles (quick add, voice add), Quick Ball overlay service, share target (`SEND`,
  `SEND_MULTIPLE`), `PROCESS_TEXT` action, voice recorder + AI transcription, ML Kit document scanner.
- Reminders: exact alarms, full-screen intents, "annoying alert" (constant reminder), geofence location reminders.
- Focus: Pomodoro/stopwatch foreground services, floating timer window, full-screen timer, flip-to-focus, named timers.
- Watches: Wear OS, Huawei, Honor, Xiaomi, Vivo. AI assistant in a WebView with a JS bridge (115 classes).
- New entities vs 2021: `Countdown` (types countdown/anniversary/birthday/holiday, count-up, lunar calendar, 8 styles,
  ignoreYear, showAge, daysOption), `Timer` (name, type, objType task/habit, objId, pomodoroTime),
  `Location` (lat, lng, radius, transitionType), `Habit` adds `currentStreak`, `maxStreak`, `exDates`.

## Note
TickTick's own APK link (`download.ticktick.app/download/apk/gnotes.apk`) serves GNotes (`org.dayup.gnotes` 1.8.4.5),
not TickTick.
