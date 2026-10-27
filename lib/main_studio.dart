import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/logger/app_logger.dart';
import 'data/database/projects_database.dart';
import 'features/studio/studio_app.dart';

/// Standalone entry point for AI Engineering Studio.
/// Builds and runs independently from SyncTask.
Future<void> main([List<String> args = const []]) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final projectsDb = await ProjectsDatabase.open();

  runApp(StudioApp(projectsDb: projectsDb));
}
