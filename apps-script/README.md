# apps-script/

Optional server-side jobs that run inside Google, bound to the SheetTick spreadsheet.
Not needed for phase 0.

Planned (phase 3):
- **Nightly archive and compaction**: move completed tasks older than a year to an archive spreadsheet,
  physically remove tombstoned rows under `LockService`, then bump `meta.compaction_epoch`.
- **Fallback reminders**: email (or ntfy/Telegram) for tasks flagged critical, in case no device is on.

Deploy with clasp only: `clasp push`, `clasp create-version "<msg>"`, `clasp update-deployment <id> --versionNumber N`.
