import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/floating_panel/floating_bubble_overlay.dart';
import '../features/settings/settings_controller.dart';
import '../features/tasks/tasks_page.dart';

class SyncTaskApp extends StatelessWidget {
  const SyncTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final seedColor = settings.themeSeedColor;

    final lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );

    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ).copyWith(
        surface: settings.isAmoledDark ? Colors.black : null,
      ),
      scaffoldBackgroundColor: settings.isAmoledDark ? Colors.black : null,
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        color: settings.isAmoledDark ? const Color(0xFF121212) : null,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );

    return MaterialApp(
      title: 'SyncTask',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: const FloatingBubbleOverlay(child: TasksPage()),
    );
  }
}
