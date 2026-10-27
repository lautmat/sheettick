/// A task's `priority` column, with TickTick's values (see `docs/sheet-schema.md`).
enum Priority {
  none(0, 'None'),
  low(1, 'Low'),
  medium(3, 'Medium'),
  high(5, 'High');

  const Priority(this.value, this.label);

  /// The value stored in the local row and in the Sheet.
  final int value;
  final String label;

  /// The priority stored as [value]. A value typed by hand that is not one of the four counts as the nearest one
  /// below it, so `4` is medium and anything below `1` is none.
  static Priority of(int value) {
    if (value >= high.value) return high;
    if (value >= medium.value) return medium;
    if (value >= low.value) return low;
    return none;
  }
}
