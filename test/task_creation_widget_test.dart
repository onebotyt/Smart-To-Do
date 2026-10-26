import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synctask/app/app.dart';
import 'package:synctask/data/database/app_database.dart';
import 'package:synctask/data/repositories/task_repository.dart';
import 'package:synctask/features/settings/settings_controller.dart';
import 'package:synctask/features/tasks/task_controller.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('create a new task through the UI and verify filter toggle', (tester) async {
    late SettingsController settings;
    late Database db;
    late String deviceId;

    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      settings = await SettingsController.load();
      db = await AppDatabase.open(path: inMemoryDatabasePath);
      deviceId = await AppDatabase.deviceId(db);
    });

    addTearDown(() async => await db.close());
    final repo = TaskRepository(db, deviceId);
    final taskController = TaskController(repo, settings);
    await tester.runAsync(() async {
      await taskController.refresh();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: taskController),
        ],
        child: const SyncTaskApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify empty state is displayed initially
    expect(find.text('All caught up!'), findsOneWidget);

    // Tap Floating Action Button to navigate to TaskEditPage
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify TaskEditPage is displayed
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('New Task')),
      findsOneWidget,
    );

    // Enter task details: Note (unified note-first input) and Category
    await tester.enterText(
        find.byType(TextFormField).first, 'Write Milestone 1 Tests');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Category (Optional)'), 'Engineering');
    await tester.pump();

    await tester.tap(find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.check),
    ));
    await tester.pumpAndSettle();

    // Verify returned to TasksPage and task is displayed
    expect(find.text('Write Milestone 1 Tests'), findsOneWidget);

    // Verify task is persisted in repository
    final tasks = await repo.list();
    expect(tasks.length, 1);
    expect(tasks.first.title, 'Write Milestone 1 Tests');
    expect(tasks.first.category, 'Engineering');
    expect(tasks.first.completed, isFalse);

    // Verify category chip is shown
    expect(find.text('Engineering'), findsWidgets);

    // Test Pending / Done toggle: switch to Done
    await tester.tap(find.textContaining('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Write Milestone 1 Tests'), findsNothing);

    // Switch back to Pending
    await tester.tap(find.textContaining('Pending'));
    await tester.pumpAndSettle();
    expect(find.text('Write Milestone 1 Tests'), findsOneWidget);
  });
}
