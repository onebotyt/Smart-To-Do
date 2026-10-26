import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'data/database/app_database.dart';
import 'data/repositories/task_repository.dart';
import 'features/settings/settings_controller.dart';
import 'features/tasks/task_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final db = await AppDatabase.open();
  final deviceId = await AppDatabase.deviceId(db);
  final repo = TaskRepository(db, deviceId);
  final settings = await SettingsController.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => TaskController(repo, settings)..refresh()),
      ],
      child: const SyncTaskApp(),
    ),
  );
}
