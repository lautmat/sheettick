import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tasks/smart_lists.dart';

/// The list the user picked in the sidebar, by id. Null means the Inbox.
class SelectedListId extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedListIdProvider = NotifierProvider<SelectedListId, String?>(SelectedListId.new);

/// The smart list on screen, or null when the picked list (or the Inbox) is. It wins over [selectedListIdProvider].
class SelectedSmartList extends Notifier<SmartList?> {
  @override
  SmartList? build() => null;

  void select(SmartList? list) => state = list;
}

final selectedSmartListProvider = NotifierProvider<SelectedSmartList, SmartList?>(SelectedSmartList.new);

/// Shows the list [id] (null: the Inbox), leaving any smart list.
void openList(WidgetRef ref, String? id) {
  ref.read(selectedSmartListProvider.notifier).select(null);
  ref.read(selectedListIdProvider.notifier).select(id);
}

/// The list on screen: the picked list while it is live (not deleted, not archived), otherwise the Inbox. Null
/// until the Inbox exists, which is before the first sign-in has synced it down.
final activeListProvider = StreamProvider<TaskList?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final picked = ref.watch(selectedListIdProvider);
  final query = db.select(db.lists)..where((l) => l.deleted.equals(false) & l.archived.equals(false));
  return query.watch().map((rows) {
    final hit = picked == null ? null : rows.where((l) => l.id == picked).firstOrNull;
    return hit ?? rows.where((l) => l.isInbox).firstOrNull;
  });
});

/// Every list that is not deleted, archived ones included: the sidebar shows them all. The Inbox comes first.
final sidebarListsProvider = StreamProvider<List<TaskList>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.lists)
    ..where((l) => l.deleted.equals(false))
    ..orderBy([
      (l) => OrderingTerm.desc(l.isInbox),
      (l) => OrderingTerm.asc(l.sortOrder),
      (l) => OrderingTerm.asc(l.name),
    ]);
  return query.watch();
});

/// Folders that are not deleted, in their order.
final foldersProvider = StreamProvider<List<Folder>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.folders)
    ..where((f) => f.deleted.equals(false))
    ..orderBy([(f) => OrderingTerm.asc(f.sortOrder), (f) => OrderingTerm.asc(f.name)]);
  return query.watch();
});
