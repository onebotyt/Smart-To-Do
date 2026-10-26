import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/settings/settings_controller.dart';
import '../features/tasks/tasks_page.dart';

class SyncTaskApp extends StatelessWidget {
  const SyncTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return MaterialApp(
      title: 'SyncTask',
      themeMode: settings.themeMode,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const TasksPage(),
    );
  }
}
