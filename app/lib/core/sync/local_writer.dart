import 'package:uuid/uuid.dart';

import '../time.dart';
import 'local_store.dart';
import 'record.dart';

/// How the app changes local rows. It applies the write rules of `CLAUDE.md`: every write bumps `version`,
/// sets `updated_at` (UTC) and `device`, and marks the row dirty so the next sync pushes it.
class LocalWriter {
  LocalWriter(this.store, {required this.deviceId, DateTime Function()? clock, String Function()? newId})
    : _clock = clock ?? DateTime.now,
      _newId = newId ?? (() => const Uuid().v4());

  final LocalStore store;
  final String deviceId;
  final DateTime Function() _clock;
  final String Function() _newId;

  /// Inserts a new row into [tab] and returns its `id`. [values] holds the entity columns; `id` is generated
  /// when absent.
  Future<String> insert(String tab, Fields values) async {
    final now = formatUtc(_clock());
    final id = (values['id'] as String?) ?? _newId();
    final fields = await store.normalize(tab, {
      ...values,
      'id': id,
      'created_at': now,
      'updated_at': now,
      'version': 1,
      'device': deviceId,
      'deleted': false,
    });
    // putRow is an upsert; a caller-supplied id that already exists must not silently replace that row.
    await store.transaction(() async {
      if (await store.getRow(tab, id) != null) throw StateError('A $tab row with id $id already exists');
      await store.putRow(tab, LocalRow(fields: fields, dirty: true));
    });
    return id;
  }

  /// Applies [changes] to the row [id]. Throws if the row does not exist.
  Future<void> update(String tab, String id, Fields changes) async {
    await store.transaction(() async {
      final row = await store.getRow(tab, id) ?? (throw StateError('No $tab row $id'));
      final fields = await store.normalize(tab, {
        ...row.fields,
        ...changes,
        'id': id,
        'updated_at': formatUtc(_clock()),
        'version': row.version + 1,
        'device': deviceId,
      });
      await store.putRow(tab, row.copyWith(fields: fields, dirty: true));
    });
  }

  /// Tombstones the row: rows are never removed.
  Future<void> delete(String tab, String id) => update(tab, id, {'deleted': true});
}
