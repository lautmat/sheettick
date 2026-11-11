import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/sync/local_writer.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/undo/undo.dart';

/// How long the Undo snackbar stays up.
const kUndoDuration = Duration(seconds: 6);

/// The last change that can still be undone, or null. A new change replaces it: only the last one is offered.
class UndoState extends Notifier<UndoEntry?> {
  @override
  UndoEntry? build() => null;

  void offer(UndoEntry entry) => state = entry;

  /// Reverses [entry] and, when it is still the last change, forgets it so it cannot be undone twice.
  Future<void> undo(UndoEntry entry) async {
    final writer = await ref.read(localWriterProvider.future);
    await applyUndo(writer, entry);
    ref.read(syncControllerProvider.notifier).requestSoon();
    if (identical(state, entry)) state = null;
  }
}

final undoProvider = NotifierProvider<UndoState, UndoEntry?>(UndoState.new);

/// Runs [body] as one write through the local writer, asks for a sync, and offers to undo it.
///
/// [rows] are the rows [body] may change (see [recordUndo]); [created] says which rows its result made.
Future<T> changeWithUndo<T>(
  WidgetRef ref,
  String label,
  List<RowRef> rows,
  Future<T> Function(LocalWriter writer) body, {
  Iterable<RowRef> Function(T result)? created,
}) async {
  final writer = await ref.read(localWriterProvider.future);
  late T result;
  final entry = await recordUndo(writer, label, rows, () async {
    result = await body(writer);
    return created?.call(result) ?? const <RowRef>[];
  });
  ref.read(syncControllerProvider.notifier).requestSoon();
  if (entry != null) ref.read(undoProvider.notifier).offer(entry);
  return result;
}

/// Shows the snackbar with an Undo button for each change offered. It sits above every page, so the snackbar stays
/// up when the page that made the change closes.
class UndoHost extends ConsumerWidget {
  const UndoHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<UndoEntry?>(undoProvider, (previous, entry) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (entry == null || messenger == null) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(entry.label),
            duration: kUndoDuration,
            // A snackbar with an action stays up until dismissed unless told otherwise; this one is a short offer.
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  await ref.read(undoProvider.notifier).undo(entry);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Could not undo: $e')));
                }
              },
            ),
          ),
        );
    });
    return child;
  }
}
