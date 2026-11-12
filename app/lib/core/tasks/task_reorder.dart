/// A task's place among the others: its id and its `sort_order`.
typedef Placed = ({String id, double order});

/// The `sort_order` values to write so that [moving] ends up just before the task [beforeId] (at the end when it is null
/// or not among the others), given [shown], the tasks of that place in the order they are shown.
///
/// [shown] may or may not hold [moving]. The result maps task id to its new `sort_order` and is empty when nothing has
/// to change (the task is dropped where it already is). Most of the time it holds one entry, a number between its two
/// new neighbours. New tasks are written with the same `sort_order` (0), so neighbours can be equal; then the whole
/// place is numbered 1, 2, 3... and every task whose number changed is in the result.
Map<String, double> placeBefore(List<Placed> shown, Placed moving, String? beforeId) {
  final others = [for (final t in shown) if (t.id != moving.id) t];
  var index = beforeId == null ? others.length : others.indexWhere((t) => t.id == beforeId);
  if (index < 0) index = others.length;

  if (shown.indexWhere((t) => t.id == moving.id) == index) return const {};

  final prev = index > 0 ? others[index - 1].order : null;
  final next = index < others.length ? others[index].order : null;
  final double between = switch ((prev, next)) {
    (null, null) => 1,
    (final double p, null) => p + 1,
    (null, final double n) => n - 1,
    (final double p, final double n) => (p + n) / 2,
  };
  // Neighbours that are equal, out of order, or too close for a number to fit between them mean a renumbering.
  final fits = (prev == null || prev < between) && (next == null || between < next);
  if (fits) return {moving.id: between};

  final ordered = [...others.sublist(0, index), moving, ...others.sublist(index)];
  return {
    for (var i = 0; i < ordered.length; i++)
      if (ordered[i].order != i + 1.0) ordered[i].id: i + 1.0,
  };
}
