import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synctask/data/database/app_database.dart';
import 'package:synctask/data/repositories/device_repository.dart';
import 'package:synctask/data/repositories/task_repository.dart';
import 'package:synctask/features/floating_panel/floating_task_panel.dart';
import 'package:synctask/features/settings/settings_controller.dart';
import 'package:synctask/features/sync/sync_controller.dart';
import 'package:synctask/features/tasks/task_controller.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('FloatingTaskPanel allows quick task entry and completion toggle',
      (tester) async {
    late Database db;
    late String deviceId;
    late SettingsController settings;
    late TaskRepository taskRepo;
    late DeviceRepository deviceRepo;
    late SyncController syncController;
    late TaskController taskController;

    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      settings = await SettingsController.load();
      db = await AppDatabase.open(path: inMemoryDatabasePath);
      deviceId = await AppDatabase.deviceId(db);
      taskRepo = TaskRepository(db, deviceId);
      deviceRepo = DeviceRepository(db);
      syncController = SyncController(taskRepo: taskRepo, deviceRepo: deviceRepo);
      await syncController.init();
      taskController = TaskController(taskRepo, settings);
      await taskController.refresh();
    });

    addTearDown(() async => await db.close());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: taskController),
          ChangeNotifierProvider.value(value: syncController),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: FloatingTaskPanel(),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify initial empty state
    expect(find.text('SyncTask'), findsOneWidget);
    expect(find.text('All caught up! 🎉'), findsOneWidget);
    expect(find.text('Add quick task...'), findsOneWidget);

    // Enter a new quick task
    await tester.enterText(find.byType(TextField), 'Quick Floating Task');
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pumpAndSettle();

    // Verify task appears in the list
    expect(find.text('Quick Floating Task'), findsOneWidget);
    expect(find.text('1'), findsWidgets); // Badge count

    // Toggle completion checkbox
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    // In "Pending only" mode, completed task disappears
    expect(find.text('All caught up! 🎉'), findsOneWidget);

    // Toggle off "Pending only" filter
    await tester.tap(find.text('Pending only'));
    await tester.pumpAndSettle();

    // Completed task is visible again with strikethrough
    expect(find.text('Quick Floating Task'), findsOneWidget);
  });
}
