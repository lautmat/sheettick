import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/parse/quick_add.dart';
import '../../core/parse/quick_add_edit.dart';
import '../../core/tasks/priority.dart';
import '../../core/tasks/task_dates.dart';
import '../lists/lists_providers.dart';
import '../tasks/task_attributes.dart';

/// The row of buttons under the quick-add field: Today, Tomorrow, Priority, List and Tag. A button does not set a field
/// of its own: it edits the text (see `quick_add_edit.dart`), and what the text says is read by the same parser as
/// when it is typed, so the preview and the task made from it agree with the button.
///
/// Today and Tomorrow are toggles that light up when the text names that day. Priority, List and Tag open a menu with a
/// tick on what the text has now; choosing the ticked item takes it out again.
class QuickAddChips extends ConsumerWidget {
  const QuickAddChips({super.key, required this.text, required this.zone, required this.onEdit, this.onMenu});

  /// The text in the field.
  final String text;

  /// The device's IANA zone, which says what "today" is.
  final String zone;

  /// Called with the text after a button's edit.
  final ValueChanged<String> onEdit;

  /// Called with true when one of the menus opens and false when it closes. The bar must stay on screen while a menu is
  /// open, or the choice would be lost.
  final ValueChanged<bool>? onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = TaskDates(zone: zone).wallOf(DateTime.now());
    final parsed = parseQuickAdd(text, now: now, zone: zone, allowEmptyTitle: true);
    final today = dayOf(now);
    final hasDay = parsed.spans[QuickAddPart.day]?.isNotEmpty ?? false;
    bool dayIs(int offset) {
      final due = parsed.dates.due;
      return hasDay && due != null && daysBetween(today, due) == offset;
    }

    final lists = [
      for (final l in ref.watch(sidebarListsProvider).value ?? const [])
        if (!l.archived && quickAddListToken(l.name) != null) l.name,
    ];
    final tags = [
      for (final t in ref.watch(tagNamesProvider).value ?? const <String>[])
        if (quickAddTagToken(t) != null) t,
    ];
    final priority = parsed.priority;
    final chosenList = parsed.listName?.toLowerCase();

    Widget gap() => const SizedBox(width: 8);

    // The field keeps the keyboard while a button is used: the buttons take no focus, and a click on them does not
    // count as one outside the field (on a desktop that drops the field's focus as the button goes down, which on an
    // empty field would take the buttons away before the click landed).
    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (key, label, offset, word) in const [
                ('chipToday', 'Today', 0, 'today'),
                ('chipTomorrow', 'Tomorrow', 1, 'tomorrow'),
              ]) ...[
                FilterChip(
                  key: Key(key),
                  label: Text(label),
                  selected: dayIs(offset),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onEdit(setQuickAddDay(text, dayIs(offset) ? null : word, now: now, zone: zone)),
                ),
                gap(),
              ],
              _MenuChip<int>(
                key: const Key('chipPriority'),
                label: priority == null || priority == 0 ? 'Priority' : Priority.of(priority).label,
                icon: priority == null || priority == 0 ? Icons.outlined_flag : Icons.flag,
                iconColor: priority == null ? null : priorityColor(Priority.of(priority)),
                selected: priority != null && priority != 0,
                onMenu: onMenu,
                items: [
                  for (final p in const [Priority.high, Priority.medium, Priority.low, Priority.none])
                    (value: p.value, label: p.label, ticked: Priority.of(priority ?? 0) == p),
                ],
                // Choosing the ticked priority takes it out of the text, like choosing None.
                onChosen: (value) => onEdit(
                  setQuickAddPriority(text, Priority.of(priority ?? 0).value == value ? null : value, now: now, zone: zone),
                ),
              ),
              gap(),
              if (lists.isNotEmpty) ...[
                _MenuChip<String>(
                  key: const Key('chipList'),
                  label: parsed.listName ?? 'List',
                  icon: Icons.list_alt,
                  selected: parsed.listName != null,
                  onMenu: onMenu,
                  items: [for (final name in lists) (value: name, label: name, ticked: name.toLowerCase() == chosenList)],
                  onChosen: (name) =>
                      onEdit(setQuickAddList(text, name.toLowerCase() == chosenList ? null : name, now: now, zone: zone)),
                ),
                gap(),
              ],
              if (tags.isNotEmpty)
                _MenuChip<String>(
                  key: const Key('chipTag'),
                  label: parsed.tags.isEmpty ? 'Tag' : parsed.tags.map((t) => '#$t').join(' '),
                  icon: Icons.sell_outlined,
                  selected: parsed.tags.isNotEmpty,
                  onMenu: onMenu,
                  items: [
                    for (final name in tags)
                      (value: name, label: '#$name', ticked: parsed.tags.any((t) => t.toLowerCase() == name.toLowerCase())),
                  ],
                  onChosen: (name) => onEdit(toggleQuickAddTag(text, name, now: now, zone: zone)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chip that opens a menu of [items]; a ticked item is what the text has now.
class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.items,
    required this.onChosen,
    this.iconColor,
    this.onMenu,
  });

  final String label;
  final IconData icon;
  final Color? iconColor;
  final bool selected;
  final List<({T value, String label, bool ticked})> items;
  final ValueChanged<T> onChosen;
  final ValueChanged<bool>? onMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<T>(
      tooltip: label,
      onOpened: () => onMenu?.call(true),
      onCanceled: () => onMenu?.call(false),
      onSelected: (value) {
        onMenu?.call(false);
        onChosen(value);
      },
      itemBuilder: (_) => [
        for (final item in items)
          PopupMenuItem<T>(
            value: item.value,
            child: Row(
              children: [
                SizedBox(width: 24, child: item.ticked ? const Icon(Icons.check, size: 18) : null),
                const SizedBox(width: 8),
                Flexible(child: Text(item.label, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
      child: Chip(
        avatar: Icon(icon, size: 18, color: iconColor),
        label: Text(label),
        visualDensity: VisualDensity.compact,
        backgroundColor: selected ? scheme.secondaryContainer : null,
      ),
    );
  }
}
