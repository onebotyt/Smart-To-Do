import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/floating_panel/desktop_floating_bubble.dart';
import '../features/floating_panel/desktop_floating_panel.dart';
import '../features/settings/settings_controller.dart';
import '../features/tasks/tasks_page.dart';
import '../platform/window_service.dart';

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
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
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
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: settings.isAmoledDark ? const Color(0xFF121212) : null,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );

    return ValueListenableBuilder<AppWindowMode>(
      valueListenable: PlatformWindowService.currentMode,
      builder: (context, windowMode, _) {
        Widget content;
        if (Platform.isWindows && windowMode == AppWindowMode.bubble) {
          content = const DesktopFloatingBubble();
        } else if (Platform.isWindows && windowMode == AppWindowMode.panel) {
          content = DesktopFloatingPanel(
            onClose: () => PlatformWindowService.setWindowMode(AppWindowMode.bubble),
            onExpand: () => PlatformWindowService.setWindowMode(AppWindowMode.normal),
          );
        } else {
          content = const TasksPage();
        }

        return MaterialApp(
          title: 'SyncTask',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: lightTheme,
          darkTheme: darkTheme,
          home: content,
        );
      },
    );
  }
}
