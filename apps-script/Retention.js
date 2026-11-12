// Pure helpers for the nightly snapshot. No Apps Script services in here, so `node --test apps-script` can run them.

var BACKUP_PREFIX = 'SheetTick backup ';
var BACKUP_KEEP = 30;

/** "SheetTick backup 2026-11-12 03:00Z": UTC, so the names sort in time order. */
function backupName(date) {
  var iso = date.toISOString(); // 2026-11-12T03:00:41.000Z
  return BACKUP_PREFIX + iso.slice(0, 10) + ' ' + iso.slice(11, 16) + 'Z';
}

/**
 * The copies to trash: everything beyond the newest `keep` snapshots. `files` are {id, name, created} with `created`
 * in epoch milliseconds. A file whose name does not start with the snapshot prefix is never returned, so a stray file
 * dropped in the folder by hand is left alone.
 */
function expiredBackups(files, keep) {
  var mine = files.filter(function (f) { return f.name.indexOf(BACKUP_PREFIX) === 0; });
  mine.sort(function (a, b) {
    if (a.created !== b.created) return b.created - a.created; // newest first
    return a.name < b.name ? 1 : a.name > b.name ? -1 : 0;
  });
  return mine.slice(keep);
}

if (typeof module !== 'undefined') module.exports = { BACKUP_PREFIX, BACKUP_KEEP, backupName, expiredBackups };
