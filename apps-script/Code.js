// Nightly snapshot of the SheetTick spreadsheet. Bound to the spreadsheet; deployed with clasp (see README.md).
// Copies the spreadsheet into the Drive folder "SheetTick Backups" and keeps the newest 30 copies. Older copies go
// to the Drive trash (30 days to take them back), never straight to deletion.

var BACKUP_FOLDER_NAME = 'SheetTick Backups';

/** Run by the daily trigger. */
function snapshotNow() {
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) throw new Error('Another snapshot is running');
  try {
    var file = DriveApp.getFileById(SpreadsheetApp.getActive().getId());
    var folder = backupFolder_();
    var copy = file.makeCopy(backupName(new Date()), folder);
    // Only after the new copy exists is anything old thrown away.
    var expired = expiredBackups(listBackups_(folder), BACKUP_KEEP);
    expired.forEach(function (f) { DriveApp.getFileById(f.id).setTrashed(true); });
    console.log('Snapshot ' + copy.getName() + ' (' + copy.getId() + '); trashed ' + expired.length + ' old.');
  } finally {
    lock.releaseLock();
  }
}

/** Run once by hand from the script editor (it asks for permission the first time): sets the daily trigger and takes a first snapshot. */
function installTrigger() {
  ScriptApp.getProjectTriggers()
    .filter(function (t) { return t.getHandlerFunction() === 'snapshotNow'; })
    .forEach(function (t) { ScriptApp.deleteTrigger(t); });
  ScriptApp.newTrigger('snapshotNow').timeBased().everyDays(1).atHour(3).create(); // about 03:00 UTC
  snapshotNow();
}

function backupFolder_() {
  var it = DriveApp.getFoldersByName(BACKUP_FOLDER_NAME);
  return it.hasNext() ? it.next() : DriveApp.createFolder(BACKUP_FOLDER_NAME);
}

function listBackups_(folder) {
  var out = [];
  var it = folder.getFiles();
  while (it.hasNext()) {
    var f = it.next();
    out.push({ id: f.getId(), name: f.getName(), created: f.getDateCreated().getTime() });
  }
  return out;
}
