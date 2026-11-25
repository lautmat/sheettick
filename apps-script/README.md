# apps-script/

Server-side jobs that run inside Google, bound to the SheetTick spreadsheet. The app does not depend on them.

## Nightly snapshot (live since phase 1, #63)

`snapshotNow()` (in `Code.js`) copies the spreadsheet into the Drive folder **SheetTick Backups** and keeps the newest
30 copies named `SheetTick backup YYYY-MM-DD HH:MMZ` (UTC). Older copies go to the Drive trash, not to deletion, and
a file in the folder whose name does not start with `SheetTick backup` is never touched. The daily trigger runs at about
03:00 UTC. To get a spreadsheet back from a copy, see [`docs/restore-from-backup.md`](../docs/restore-from-backup.md).

- The keep-30 rule is in `Retention.js`, with no Apps Script calls, so it is tested from Node:
  `node --test apps-script/test/*.test.js` (run in CI). With a bare directory argument, Node 22 fails.
- The project needs the full `drive` scope: `DriveApp.createFolder`, `File.makeCopy` and `File.setTrashed` list no other
  scope in Google's reference, and `drive.readonly` cannot create or trash anything. That is the script's own consent
  and has nothing to do with the app's `drive.file` scope.
- `.claspignore` keeps `test/` and this README out of the script project.

### Deploying (clasp only, never the browser editor)

```
cd apps-script
clasp push -f                      # -f: the manifest in this folder is the one to keep
clasp create-version "<message>"
```

The trigger runs the saved code (HEAD), so a push is enough to change what runs; the version is a record. The watch
endpoint below is a web app, which runs a fixed version: see there. `.clasp.json` (script id and the spreadsheet it is
bound to) is committed; `~/.clasprc.json` is not and never goes in git.

Gotchas, learned the first time:
- `clasp create --type sheets --parentId <id>` ignores the parent and makes a **new, empty** spreadsheet. To bind to an
  existing one, pass `--parentId` alone.
- `clasp create` overwrites `appsscript.json` with a default (wrong time zone, no scopes). Restore it from git, then push.
- `invalid_rapt`: `clasp logout`, then `clasp login --redirect-port 8123` and approve in the browser.

### The one manual step

A trigger can only be created by running code once with permission. Open the script from the spreadsheet
(Extensions → Apps Script), choose `installTrigger`, click Run and grant the permissions. It sets the daily trigger and
takes the first snapshot at once.

## Watch endpoint (#107)

`doGet` in `WebApp.js` serves the SheetTick app on a Garmin watch (`garmin/README.md`): today's tasks
(`?a=today&tzo=<offset>`) and completing one (`?a=done&id=…&ver=…&dev=…`). Every call needs `k=<token>`, compared with
`WATCH_TOKEN` in `WatchSecret.js`. That file is git-ignored, but clasp pushes it. `node tools/watch_secrets.mjs` writes
it, and the same token goes into the watch app. The logic is in `Today.js` with no Apps Script calls, tested from Node
like `Retention.js`.

- The manifest's `webapp` block: runs as the owner, callable by anyone with the URL (the token is the lock). It needs no
  scope beyond `spreadsheets.currentonly`, which the script already has.
- Writes go through `LockService` and touch only the cells that change. Text cells are kept as plain text, so a
  timestamp never becomes a date serial.
- One deployment, described "Garmin watch endpoint" (`clasp list-deployments` shows its id). Its URL is kept out of
  this public repo, in the two secrets files. A web app runs the version it was deployed at, not HEAD, so after a change:
  ```
  clasp push -f
  clasp create-version "<message>"                  # prints version N
  clasp update-deployment <deployment id> -V N      # same /exec URL, nothing to change on the watch
  ```

## Planned (phase 3)
- **Nightly archive and compaction**: move completed tasks older than a year to an archive spreadsheet,
  physically remove tombstoned rows under `LockService`, then bump `meta.compaction_epoch`.
- **Fallback reminders**: email (or ntfy/Telegram) for tasks flagged critical, in case no device is on.
