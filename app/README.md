# app/

The Flutter app lives here. It is generated in phase 0:

```
flutter create --org com.lmathieu --project-name sheettick --platforms=windows,android .
```

Planned layout after generation:

```
lib/
  main.dart
  core/          pure Dart: models, drift database, sync engine, date parser, recurrence
    db/
    sheets/      Sheets + Drive API client, sheet bootstrap
    sync/
    auth/
  features/      UI per feature: lists, task_detail, quick_add, calendar, kanban, focus, habits...
test/            unit tests for core/ (sync conflict tests are mandatory)
secrets/         git-ignored OAuth client files (see secrets/README.md)
```
