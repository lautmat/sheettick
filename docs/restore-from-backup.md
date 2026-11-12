# Restoring from a nightly copy

The Apps Script job in `apps-script/` copies the spreadsheet every night into the Drive folder **SheetTick Backups**
(newest 30 kept, named `SheetTick backup YYYY-MM-DD HH:MMZ`, UTC). Copies it trashes stay in the Drive trash for 30 days.

The app finds its spreadsheet by id and, with the `drive.file` scope, only sees the file it created. **A copy is a
different file, so the app can never open it.** Restoring therefore means putting the copy's *contents* back into the
original spreadsheet, and then making the devices take them.

## Why the devices need a reset
On a pull, a device takes a Sheet row only when its `version` is higher than the local one. After a restore the Sheet
holds older rows. A device whose copy is newer does not see a change to take and, having nothing dirty, never pushes
those rows back. So the Sheet and the devices would disagree for good. Resetting the local database fixes it: the
device then pulls everything from the restored Sheet.

Anything written after the copy was taken exists only in the devices' databases until the reset. If you want it, note
it first (or use "Restoring a few rows" below instead).

## Restoring everything
1. Close SheetTick on every device, or sign out, so nothing syncs during the restore.
2. Open the folder **SheetTick Backups** and pick the copy to go back to. Its name is its date and time in UTC.
3. Optional safety net: in the original spreadsheet, **File → Make a copy** first, so this moment can be undone too.
4. For every tab of the copy except `View` (`tasks`, `checklist`, `lists`, `folders`, `sections`, `tags`, `meta`
   and the other entity tabs listed in `sheet-schema.md`), in the original spreadsheet: select the whole tab, clear it,
   then in the copy select all, copy, and paste at cell A1 of the same tab in the original. `View` is made of formulas
   and rebuilds itself. Keep the tab names and the header row exactly as they are, and do not delete a tab: the app
   finds tabs by name.
5. Reset the local database on each device, then start the app. It signs in, finds the same spreadsheet and pulls.
   - **Windows:** quit the app, delete `Documents\sheettick.sqlite` (and `sheettick.sqlite-wal` / `-shm` if present).
     The app keeps its sign-in separately, so it stays signed in.
   - **Android:** Settings → Apps → SheetTick → Storage → Clear storage, then sign in again.
6. Check a few tasks, then reopen the app on the other devices.

## Restoring a few rows
When only some rows were damaged, leave the devices alone:
1. In the copy, find the rows (by `id` or title) and copy them.
2. In the original, find the row with the same `id` and paste over it, or append the row if it is gone.
3. Set `version` on that row **higher than the current value in the original** (for example current + 10). The devices
   take the row because its version is higher.

## Checking the copies are being made
Open the folder in Drive: there should be one new copy a day. In the spreadsheet, Extensions → Apps Script →
Executions lists each run and its errors.
