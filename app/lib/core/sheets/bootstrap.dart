import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../time.dart';
import 'sheet_schema.dart';
import 'sheets_backend.dart';

class BootstrapResult {
  const BootstrapResult({required this.spreadsheetId, required this.created, required this.inboxListId});

  final String spreadsheetId;

  /// True when this run created the spreadsheet (first device); false when it found an existing one.
  final bool created;
  final String inboxListId;
}

/// The Sheet was written by a newer version of the app than this one.
class SchemaTooNewException implements Exception {
  SchemaTooNewException(this.found, this.supported);
  final int found;
  final int supported;
  @override
  String toString() => 'SchemaTooNewException: sheet schema $found is newer than supported $supported';
}

/// A tab's header row lacks columns the schema requires (hand-edited header).
class SchemaMismatchException implements Exception {
  SchemaMismatchException(this.tab, this.missingColumns);
  final String tab;
  final List<String> missingColumns;
  @override
  String toString() => 'SchemaMismatchException: tab "$tab" is missing columns $missingColumns';
}

/// The spreadsheet this device used before is gone or trashed. The caller decides what to do (re-link,
/// restore from the trash, or start over); bootstrap never silently creates a replacement.
class SpreadsheetMissingException implements Exception {
  SpreadsheetMissingException(this.spreadsheetId);
  final String spreadsheetId;
  @override
  String toString() => 'SpreadsheetMissingException: $spreadsheetId';
}

/// First sign-in setup from `docs/sync-protocol.md`: find or create the spreadsheet, make sure every tab,
/// header row, the `meta` rows and the Inbox list exist. Safe to run again at any time (a crash halfway just
/// resumes) and on a second device (it finds the same file).
class SheetBootstrap {
  SheetBootstrap({
    required this.backend,
    required this.db,
    required this.deviceId,
    required this.appVersion,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _clock = clock ?? DateTime.now,
       _newId = newId ?? (() => const Uuid().v4());

  final SheetsBackend backend;
  final AppDatabase db;
  final String deviceId;
  final String appVersion;
  final DateTime Function() _clock;
  final String Function() _newId;

  Future<BootstrapResult> run() async {
    var spreadsheetId = await db.getDeviceState(DeviceStateKeys.spreadsheetId);
    var created = false;

    if (spreadsheetId != null) {
      if (await backend.getFile(spreadsheetId) == null) throw SpreadsheetMissingException(spreadsheetId);
    } else {
      final found = await backend.findSpreadsheets();
      if (found.isNotEmpty) {
        spreadsheetId = found.first.id;
      } else {
        final mine = await backend.createSpreadsheet(kSpreadsheetTitle);
        // Two devices signing in at the same moment each create a file. Both then agree on the oldest one,
        // and the loser moves its own (still empty) file to the trash.
        final all = await backend.findSpreadsheets();
        if (all.isNotEmpty && all.first.id != mine.id) {
          await backend.trashFile(mine.id);
          spreadsheetId = all.first.id;
        } else {
          spreadsheetId = mine.id;
          created = true;
        }
      }
      await db.setDeviceState(DeviceStateKeys.spreadsheetId, spreadsheetId);
    }

    final inboxListId = await _ensureStructure(spreadsheetId);
    return BootstrapResult(spreadsheetId: spreadsheetId, created: created, inboxListId: inboxListId);
  }

  /// Returns the id of the Inbox list.
  Future<String> _ensureStructure(String id) async {
    // 1. Tabs.
    final tabs = await backend.listTabs(id);
    final existing = {for (final t in tabs) t.title};
    final specNames = {for (final s in kTabs) s.name, kViewTabName};
    final missing = [for (final s in kTabs) if (!existing.contains(s.name)) s];
    final needView = !existing.contains(kViewTabName);
    // A file that has none of our tabs was never structured, so its leftover default tab ("Sheet1",
    // "Feuille 1", ...) is ours to remove. A partly structured file may hold the user's own tabs: keep those.
    final pristine = missing.length == kTabs.length;
    final remove = pristine ? [for (final t in tabs) if (!specNames.contains(t.title)) t.sheetId] : <int>[];
    final add = [...missing, if (needView) kViewTab];
    if (add.isNotEmpty || remove.isNotEmpty) {
      await backend.changeTabs(id, add: add, removeSheetIds: remove);
    }

    // 2. One read: every header row, plus the meta and lists data.
    final metaIndex = kTabs.length;
    final listsIndex = kTabs.indexWhere((t) => t.name == 'lists');
    final read = await backend.readRanges(id, [
      for (final s in kTabs) '${s.name}!1:1',
      'meta!A:B',
      'lists!A:AZ',
      '$kViewTabName!A1',
    ]);
    List<String> headerOf(int i) => read[i].isEmpty ? const [] : [for (final c in read[i].first) '$c'];

    // 3. Header rows: write where empty, refuse where a required column is gone.
    final headerWrites = <String, List<List<Object?>>>{};
    for (var i = 0; i < kTabs.length; i++) {
      final spec = kTabs[i];
      final header = headerOf(i);
      if (header.isEmpty) {
        headerWrites['${spec.name}!A1'] = [spec.columnNames];
      } else {
        final lacking = [for (final c in spec.columnNames) if (!header.contains(c)) c];
        if (lacking.isNotEmpty) throw SchemaMismatchException(spec.name, lacking);
      }
    }
    if (headerWrites.isNotEmpty) await backend.writeRanges(id, headerWrites);
    final viewEmpty = read[metaIndex + 2].isEmpty;
    if (viewEmpty) await backend.writeRanges(id, {'$kViewTabName!A1': [[viewFormula()]]}, userEntered: true);

    // 4. meta rows (the header was just written above when the tab is new).
    final metaRows = read[metaIndex];
    final present = <String, Object?>{
      for (final r in metaRows)
        if (r.isNotEmpty && '${r[0]}' != 'key') '${r[0]}': r.length > 1 ? r[1] : null,
    };
    final storedVersion = present[MetaKeys.schemaVersion];
    if (storedVersion != null) {
      final v = int.tryParse('$storedVersion');
      if (v != null && v > kSheetSchemaVersion) throw SchemaTooNewException(v, kSheetSchemaVersion);
    }
    final defaults = {
      MetaKeys.schemaVersion: '$kSheetSchemaVersion',
      MetaKeys.compactionEpoch: '0',
      MetaKeys.createdByAppVersion: appVersion,
      MetaKeys.settingsJson: '{}',
    };
    final metaToAdd = [for (final e in defaults.entries) if (!present.containsKey(e.key)) <Object?>[e.key, e.value]];
    if (metaToAdd.isNotEmpty) await backend.appendRows(id, 'meta', metaToAdd);

    // 5. Inbox.
    final listsHeader = headerOf(listsIndex);
    final listRows = read[metaIndex + 1]; // 'lists!A:AZ' is requested right after 'meta!A:B'
    final existingInbox = listsHeader.isEmpty ? null : _findInbox(listsHeader, listRows);
    if (existingInbox != null) return existingInbox;

    final now = formatUtc(_clock());
    final inboxId = _newId();
    final values = <String, Object?>{
      'id': inboxId,
      'name': 'Inbox',
      'kind': 'TASK',
      'view': 'list',
      'sort_order': 0,
      'is_inbox': true,
      'muted': false,
      'archived': false,
      'created_at': now,
      'updated_at': now,
      'version': 1,
      'device': deviceId,
      'deleted': false,
    };
    final names = listsHeader.isEmpty ? tabSpec('lists').columnNames : listsHeader;
    await backend.appendRows(id, 'lists', [
      [for (final n in names) values[n]],
    ]);
    return inboxId;
  }

  /// Id of the first live row whose `is_inbox` is true, or null.
  String? _findInbox(List<String> header, List<List<Object?>> rows) {
    final idCol = header.indexOf('id');
    final inboxCol = header.indexOf('is_inbox');
    final deletedCol = header.indexOf('deleted');
    bool isTrue(List<Object?> row, int col) {
      if (col < 0 || col >= row.length) return false;
      final v = row[col];
      return v == true || (v is String && v.toUpperCase() == 'TRUE');
    }

    for (final row in rows.skip(1)) {
      if (isTrue(row, inboxCol) && !isTrue(row, deletedCol) && idCol >= 0 && idCol < row.length) {
        return '${row[idCol]}';
      }
    }
    return null;
  }
}
