import 'dart:math';

import '../db/database.dart' show DeviceStateKeys;
import '../sheets/bootstrap.dart' show SchemaMismatchException, SpreadsheetMissingException;
import '../sheets/sheet_schema.dart';
import '../sheets/sheets_backend.dart';
import '../time.dart';
import 'local_store.dart';
import 'record.dart';

/// What one sync cycle did.
class SyncResult {
  const SyncResult({
    this.skipped = false,
    this.inserted = 0,
    this.updated = 0,
    this.merged = 0,
    this.pushedUpdates = 0,
    this.pushedAppends = 0,
    this.changedIds = const {},
  });

  /// Nothing changed in the Sheet and nothing was waiting locally: only the Drive check ran.
  final bool skipped;

  /// Rows taken from the Sheet: new, replaced, and three-way merged with local edits.
  final int inserted, updated, merged;

  /// Rows written to the Sheet: existing rows updated in place, new rows appended.
  final int pushedUpdates, pushedAppends;

  /// Per tab, the ids of rows the pull changed locally (for rescheduling reminders).
  final Map<String, Set<String>> changedIds;
}

class _Remote {
  _Remote(this.sheetRow, this.fields, this.hash);
  final int sheetRow;
  final Fields fields;
  final String hash;
}

class _TabView {
  _TabView(this.header, this.rows);
  final List<String> header;
  final List<_Remote> rows;
}

/// The sync cycle of `docs/sync-protocol.md` for the entity tabs [tabs] (tasks and lists in phase 0).
///
/// Local-first: the UI only touches the local store; this reconciles it with the Sheet. Everything is
/// batched: one Drive check, one `batchGet`, then at most one `batchUpdate` and one append per tab.
/// Rows stay dirty until the Sheet has accepted them, so a failed cycle loses nothing and is simply retried.
class SyncEngine {
  SyncEngine({
    required this.backend,
    required this.store,
    required this.deviceId,
    DateTime Function()? clock,
    this.tabs = const ['tasks', 'lists'],
    this.onRowsChanged,
  }) : _clock = clock ?? DateTime.now;

  final SheetsBackend backend;
  final LocalStore store;
  final String deviceId;
  final List<String> tabs;
  final DateTime Function() _clock;

  /// Called after a cycle with the rows the pull changed, to reschedule reminders for them.
  final void Function(Map<String, Set<String>> changedIds)? onRowsChanged;

  Future<SyncResult>? _inFlight;

  /// Runs a cycle. Calls made while one is running share its result instead of starting another.
  Future<SyncResult> sync() => _inFlight ??= _cycle().whenComplete(() => _inFlight = null);

  Future<SyncResult> _cycle() async {
    final spreadsheetId = await store.getState(DeviceStateKeys.spreadsheetId);
    if (spreadsheetId == null) throw StateError('Not bootstrapped: no spreadsheet id on this device');

    // 1. Change check.
    final file = await backend.getFile(spreadsheetId) ?? (throw SpreadsheetMissingException(spreadsheetId));
    final lastSeen = DateTime.tryParse(await store.getState(DeviceStateKeys.lastDriveModifiedTime) ?? '');
    final hasDirty = await store.dirtyCount(tabs) > 0;
    if (!hasDirty && lastSeen != null && file.modifiedTime == lastSeen) return const SyncResult(skipped: true);

    // 2 + 3. One read of every tab, plus meta for the compaction epoch.
    final read = await backend.readRanges(spreadsheetId, [for (final t in tabs) '$t!A:AZ', 'meta!A:B']);
    final epoch = _epochOf(read.last);
    final knownEpoch = await store.getState(DeviceStateKeys.lastCompactionEpoch);
    if (knownEpoch != null && knownEpoch != epoch) {
      for (final t in tabs) {
        await store.clearSheetRows(t);
      }
    }

    final views = <String, _TabView>{
      for (var i = 0; i < tabs.length; i++) tabs[i]: _parse(tabs[i], read[i]),
    };
    var inserted = 0, updated = 0, merged = 0;
    final changed = <String, Set<String>>{for (final t in tabs) t: {}};
    for (final tab in tabs) {
      final counts = await _pull(tab, views[tab]!, changed[tab]!);
      inserted += counts.inserted;
      updated += counts.updated;
      merged += counts.merged;
    }

    // 5. Push.
    final pushed = await _push(spreadsheetId, views);

    await store.setState(DeviceStateKeys.lastDriveModifiedTime, file.modifiedTime.toUtc().toIso8601String());
    await store.setState(DeviceStateKeys.lastCompactionEpoch, epoch);

    // 6. Reminders.
    changed.removeWhere((_, ids) => ids.isEmpty);
    if (changed.isNotEmpty) onRowsChanged?.call(changed);

    return SyncResult(
      inserted: inserted,
      updated: updated,
      merged: merged,
      pushedUpdates: pushed.updates,
      pushedAppends: pushed.appends,
      changedIds: changed,
    );
  }

  String _epochOf(List<List<Object?>> metaRows) {
    for (final r in metaRows) {
      if (r.isNotEmpty && '${r[0]}' == MetaKeys.compactionEpoch) return r.length > 1 ? '${r[1]}' : '';
    }
    return '';
  }

  // ---- Pull -----------------------------------------------------------------------------------------------

  _TabView _parse(String tab, List<List<Object?>> rows) {
    final spec = tabSpec(tab);
    if (rows.isEmpty) throw SchemaMismatchException(tab, spec.columnNames);
    final header = [for (final c in rows.first) '$c'];
    final lacking = [for (final c in spec.columnNames) if (!header.contains(c)) c];
    if (lacking.isNotEmpty) throw SchemaMismatchException(tab, lacking);

    final index = {for (final c in spec.columns) c.name: header.indexOf(c.name)};
    final seen = <String>{};
    final out = <_Remote>[];
    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i];
      final fields = <String, Object?>{
        for (final c in spec.columns)
          c.name: index[c.name]! < cells.length ? decodeCell(c.type, cells[index[c.name]!]) : null,
      };
      final id = fields['id'] as String?;
      // A row without an id cannot be tracked; if an id is duplicated (copy-pasted row), the first one wins.
      if (id == null || !seen.add(id)) continue;
      out.add(_Remote(i + 1, fields, rowHash(spec, fields)));
    }
    return _TabView(header, out);
  }

  Future<({int inserted, int updated, int merged})> _pull(String tab, _TabView view, Set<String> changed) async {
    final spec = tabSpec(tab);
    var inserted = 0, updated = 0, merged = 0;
    await store.transaction(() async {
      final locals = await store.rowsById(tab);
      final now = formatUtc(_clock());

      for (final remote in view.rows) {
        final id = remote.fields['id']! as String;
        final local = locals[id];

        if (local != null && local.syncedHash == remote.hash) {
          // Unchanged in the Sheet; just keep the cached row number current.
          if (local.sheetRow != remote.sheetRow) await store.setSheetRow(tab, id, remote.sheetRow);
          continue;
        }

        // The row as the Sheet has it, in the local representation (defaults filled in).
        final repaired = _repaired(remote.fields, now);
        final seenFields = await store.normalize(tab, repaired.fields);

        if (local == null) {
          await store.putRow(
            tab,
            LocalRow(
              fields: seenFields,
              dirty: repaired.changed,
              sheetRow: remote.sheetRow,
              syncedHash: remote.hash,
              baseSnapshot: seenFields,
            ),
          );
          inserted++;
          changed.add(id);
        } else if (!local.dirty) {
          // The Sheet changed and we have nothing pending: take it. A manual edit leaves `version` as it was
          // (or lower); bump it so the other devices see a newer row, and push that.
          var fields = seenFields;
          var dirty = repaired.changed;
          if ((fields['version']! as int) <= local.version) {
            fields = {...fields, 'version': local.version + 1, 'updated_at': now, 'device': deviceId};
            dirty = true;
          }
          await store.putRow(
            tab,
            LocalRow(
              fields: fields,
              dirty: dirty,
              sheetRow: remote.sheetRow,
              syncedHash: remote.hash,
              baseSnapshot: seenFields,
            ),
          );
          updated++;
          changed.add(id);
        } else {
          // Both sides changed: three-way merge against the last synced state.
          final mergeable = spec.columnNames.where((c) => !kUnmergedColumns.contains(c));
          final result = mergeFields(
            base: local.baseSnapshot ?? const {},
            local: local.fields,
            remote: seenFields,
            columns: mergeable,
          );
          final fields = await store.normalize(tab, {
            ...result,
            'id': id,
            'created_at': _earlier(local.fields['created_at'] as String?, seenFields['created_at'] as String?),
            'version': max(local.version, seenFields['version']! as int) + 1,
            'updated_at': now,
            'device': deviceId,
          });
          await store.putRow(
            tab,
            LocalRow(
              fields: fields,
              dirty: true,
              sheetRow: remote.sheetRow,
              syncedHash: remote.hash,
              baseSnapshot: seenFields,
            ),
          );
          merged++;
          changed.add(id);
        }
      }

      // Rows we had placed in the Sheet that are no longer there (deleted by hand): forget their position.
      // They stay local, and are appended again if they are edited.
      final present = {for (final r in view.rows) r.fields['id']! as String};
      for (final local in locals.values) {
        if (local.sheetRow != null && !present.contains(local.id)) await store.setSheetRow(tab, local.id, null);
      }
    });
    return (inserted: inserted, updated: updated, merged: merged);
  }

  /// Fills in what a row typed by hand in the Sheet lacks (`version`, `created_at`, `updated_at`), and says
  /// whether it had to, so the sync columns get written back.
  ({Fields fields, bool changed}) _repaired(Fields remote, String now) {
    final fields = {...remote};
    var changed = false;
    if (fields['version'] is! int || (fields['version']! as int) < 1) {
      fields['version'] = 1;
      changed = true;
    }
    if (fields['created_at'] == null) {
      fields['created_at'] = now;
      changed = true;
    }
    if (fields['updated_at'] == null) {
      fields['updated_at'] = fields['created_at'];
      changed = true;
    }
    return (fields: fields, changed: changed);
  }

  String? _earlier(String? a, String? b) {
    if (a == null) return b;
    if (b == null) return a;
    final ta = DateTime.tryParse(a), tb = DateTime.tryParse(b);
    if (ta == null || tb == null) return a.compareTo(b) <= 0 ? a : b;
    return ta.isBefore(tb) ? a : b;
  }

  // ---- Push -----------------------------------------------------------------------------------------------

  Future<({int updates, int appends})> _push(String spreadsheetId, Map<String, _TabView> views) async {
    final pending = <String, List<LocalRow>>{};
    for (final tab in tabs) {
      final dirty = (await store.rowsById(tab)).values.where((r) => r.dirty).toList();
      if (dirty.isNotEmpty) pending[tab] = dirty;
    }
    if (pending.isEmpty) return (updates: 0, appends: 0);

    // Before writing in place, check that the id at each cached row number is still ours. The row numbers
    // were refreshed by the pull a moment ago, but a compaction or a hand sort in between would make them wrong,
    // and a write to a wrong row corrupts another task.
    final needCheck = [for (final e in pending.entries) if (e.value.any((r) => r.sheetRow != null)) e.key];
    final idsByTab = <String, List<String?>>{};
    if (needCheck.isNotEmpty) {
      final letters = {
        for (final t in needCheck) t: columnLetter(views[t]!.header.indexOf('id')),
      };
      final reads = await backend.readRanges(spreadsheetId, [for (final t in needCheck) '$t!${letters[t]}:${letters[t]}']);
      for (var i = 0; i < needCheck.length; i++) {
        idsByTab[needCheck[i]] = [for (final r in reads[i]) r.isEmpty ? null : decodeCell(ColumnType.uuid, r.first) as String?];
      }
    }

    final updateRanges = <String, List<List<Object?>>>{};
    final updateTargets = <(String, LocalRow, int)>[];
    final appendRows = <String, List<LocalRow>>{};
    for (final entry in pending.entries) {
      final tab = entry.key;
      final header = views[tab]!.header;
      final lastColumn = columnLetter(header.length - 1);
      final ids = idsByTab[tab] ?? const <String?>[];
      final firstRowOfId = <String, int>{};
      for (var i = 0; i < ids.length; i++) {
        final id = ids[i];
        if (id != null) firstRowOfId.putIfAbsent(id, () => i + 1);
      }
      for (final row in entry.value) {
        int? target;
        final cached = row.sheetRow;
        if (cached != null) {
          target = (cached <= ids.length && ids[cached - 1] == row.id) ? cached : firstRowOfId[row.id];
        }
        if (target == null) {
          appendRows.putIfAbsent(tab, () => []).add(row);
        } else {
          updateRanges['$tab!A$target:$lastColumn$target'] = [_cells(tabSpec(tab), header, row.fields)];
          updateTargets.add((tab, row, target));
        }
      }
    }

    if (updateRanges.isNotEmpty) await backend.writeRanges(spreadsheetId, updateRanges);
    for (final (tab, row, target) in updateTargets) {
      await store.markPushed(
        tab,
        row.id,
        pushedVersion: row.version,
        sheetRow: target,
        hash: rowHash(tabSpec(tab), row.fields),
        fields: row.fields,
      );
    }

    var appended = 0;
    for (final entry in appendRows.entries) {
      final tab = entry.key;
      final header = views[tab]!.header;
      final result = await backend.appendRows(spreadsheetId, tab, [
        for (final row in entry.value) _cells(tabSpec(tab), header, row.fields),
      ]);
      for (var i = 0; i < entry.value.length; i++) {
        final row = entry.value[i];
        await store.markPushed(
          tab,
          row.id,
          pushedVersion: row.version,
          sheetRow: result.firstRow + i,
          hash: rowHash(tabSpec(tab), row.fields),
          fields: row.fields,
        );
      }
      appended += entry.value.length;
    }
    return (updates: updateTargets.length, appends: appended);
  }

  /// The cells of a row in the Sheet's own column order. Columns the schema does not know (added by the user)
  /// are `null`, which leaves them untouched.
  List<Object?> _cells(TabSpec spec, List<String> header, Fields fields) => [
    for (final h in header) spec.columnNames.contains(h) ? encodeCell(fields[h]) : null,
  ];
}
