import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/sync/sync_controller.dart';
import 'features/common/theme.dart';
import 'features/common/undo.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/reminders/reminders_providers.dart';

class SheetTickApp extends ConsumerStatefulWidget {
  const SheetTickApp({super.key});

  @override
  ConsumerState<SheetTickApp> createState() => _SheetTickAppState();
}

class _SheetTickAppState extends ConsumerState<SheetTickApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Regaining focus is a sync trigger.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncControllerProvider.notifier).sync();
      // A reminder may have been snoozed from its notification while the app was closed.
      ref.read(planRevisionProvider.notifier).bump();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the platform's reminders in step with the tasks for as long as the app runs.
    ref.watch(remindersBindingProvider);
    return MaterialApp(
      title: 'SheetTick',
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: themeModeOf(ref.watch(themeChoiceProvider).value),
      builder: (context, child) => UndoHost(child: child ?? const SizedBox.shrink()),
      home: const InboxScreen(),
    );
  }
}
