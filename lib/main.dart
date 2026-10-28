import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'core/logger/app_logger.dart';
import 'data/database/app_database.dart';
import 'data/repositories/device_repository.dart';
import 'data/repositories/task_repository.dart';
import 'features/clipboard/clipboard_controller.dart';
import 'features/media_transfer/media_transfer_controller.dart';
import 'features/settings/settings_controller.dart';
import 'features/sync/sync_controller.dart';
import 'features/tasks/task_controller.dart';
import 'data/services/cloud_sync_service.dart';
import 'core/ai/model_gateway.dart';
import 'data/database/projects_database.dart';
import 'data/repositories/memory_repository.dart';
import 'features/memory/memory_controller.dart';
import 'features/sky/sky_controller.dart';
import 'features/studio/studio_app.dart';
import 'platform/native_media_service.dart';
import 'platform/voice_service.dart';
import 'platform/window_service.dart';

const String appEdition = String.fromEnvironment('APP_EDITION', defaultValue: 'pure');
const bool isAiEdition = appEdition == 'ai';

Future<void> main([List<String> args = const []]) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  PlatformWindowService.init();

  if (args.contains('--studio')) {
    final projectsDb = await ProjectsDatabase.open();
    runApp(StudioApp(projectsDb: projectsDb));
    return;
  }

  final isBubbleArg = args.contains('--floating-bubble') || args.contains('--bubble');
  if (isBubbleArg) {
    PlatformWindowService.currentMode.value = AppWindowMode.bubble;
  }

  final db = await AppDatabase.open();
  final deviceId = await AppDatabase.deviceId(db);
  final repo = TaskRepository(db, deviceId);
  final deviceRepo = DeviceRepository(db);
  final syncController = SyncController(taskRepo: repo, deviceRepo: deviceRepo);
  await syncController.init();
  final clipboardController = ClipboardController(syncEngine: syncController.engine);
  await clipboardController.init();
  final mediaController = MediaTransferController(syncEngine: syncController.engine);
  final settings = await SettingsController.load();
  final cloudSyncService = CloudSyncService();

  final taskController = TaskController(
    repo,
    settings,
    null,
    () {
      syncController.triggerAutoSync();
      if (!isAiEdition && cloudSyncService.isAuthenticated) {
        cloudSyncService.triggerDebouncedSync(repo);
      }
    },
  )..refresh();

  cloudSyncService.onCloudTasksApplied = () {
    taskController.refresh();
  };

  if (!isAiEdition) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (cloudSyncService.isAuthenticated) {
        cloudSyncService.syncWithCloud(repo);
      }
    });
  }

  final SkyController? skyController;
  final MemoryController? memoryController;

  if (isAiEdition) {
    final memoryRepo = await MemoryRepository.open();
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final modelGateway = ManagedModelGateway(
      modelId: isMobile ? 'sky-mobile-nano' : 'sky-core',
      modelName: isMobile ? 'Sky Mobile Nano (0.5B)' : 'Sky 1.5B',
      estimatedMemoryMb: isMobile ? 380 : 500,
    );
    skyController = SkyController(
      modelGateway: modelGateway,
      memoryRepo: memoryRepo,
    );
    memoryController = MemoryController(memoryRepo);
    skyController.taskController = taskController;
    skyController.voiceService = NativeVoiceService.instance;

    taskController.onTaskCompletionChanged = (task, completed) {
      if (completed) {
        skyController?.celebrateTaskCompletion(task.title);
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 800));
      final briefing = skyController!.generateBriefing(taskController.tasks);
      skyController.speakBriefing(briefing);
    });
  } else {
    skyController = null;
    memoryController = null;
  }

  syncController.engine.onTasksReceived = () {
    taskController.refresh();
  };

  syncController.engine.onRemoteTasksApplied = (tasks) {
    for (final t in tasks) {
      if (t.deleted) continue;
      if (t.completed && isAiEdition) {
        skyController?.celebrateTaskCompletion(t.title);
      }
      if (Platform.isWindows) {
        if (t.completed) {
          NativeMediaService.notifyMediaReceived(
            title: 'SyncTask: Task Completed',
            message: '"${t.title}" was marked complete',
          );
        } else {
          NativeMediaService.notifyMediaReceived(
            title: 'SyncTask: New Task from Phone',
            message: t.title,
          );
        }
      }
    }
  };


  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: taskController),
        ChangeNotifierProvider.value(value: syncController),
        ChangeNotifierProvider.value(value: clipboardController),
        ChangeNotifierProvider.value(value: mediaController),
        if (skyController != null)
          ChangeNotifierProvider.value(value: skyController)
        else
          ChangeNotifierProvider<SkyController?>.value(value: null),
        if (memoryController != null)
          ChangeNotifierProvider.value(value: memoryController)
        else
          ChangeNotifierProvider<MemoryController?>.value(value: null),
        ChangeNotifierProvider.value(value: cloudSyncService),
      ],
      child: const SyncTaskApp(),
    ),
  );
}
