import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/sync/sync_controller.dart';
import 'features/inbox/inbox_screen.dart';

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
    if (state == AppLifecycleState.resumed) ref.read(syncControllerProvider.notifier).sync();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(colorSchemeSeed: Colors.indigo, brightness: b, useMaterial3: true);
    return MaterialApp(
      title: 'SheetTick',
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const InboxScreen(),
    );
  }
}
