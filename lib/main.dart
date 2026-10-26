import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'data/database/app_database.dart';
import 'data/repositories/device_repository.dart';
import 'data/repositories/task_repository.dart';
import 'features/clipboard/clipboard_controller.dart';
import 'features/settings/settings_controller.dart';
import 'features/sync/sync_controller.dart';
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
  final deviceRepo = DeviceRepository(db);
  final syncController = SyncController(taskRepo: repo, deviceRepo: deviceRepo);
  await syncController.init();
  final clipboardController = ClipboardController(syncEngine: syncController.engine);
  await clipboardController.init();
  final settings = await SettingsController.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => TaskController(repo, settings)..refresh()),
        ChangeNotifierProvider.value(value: syncController),
        ChangeNotifierProvider.value(value: clipboardController),
      ],
      child: const SyncTaskApp(),
    ),
  );
}
