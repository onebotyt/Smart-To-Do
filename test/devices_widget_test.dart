import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synctask/data/database/app_database.dart';
import 'package:synctask/data/models/device.dart';
import 'package:synctask/data/repositories/device_repository.dart';
import 'package:synctask/data/repositories/task_repository.dart';
import 'package:synctask/features/sync/devices_page.dart';
import 'package:synctask/features/sync/sync_controller.dart';
import 'package:synctask/features/tasks/task_controller.dart';
import 'package:synctask/features/settings/settings_controller.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('DevicesPage displays local device and generates pairing code',
      (tester) async {
    late Database db;
    late String deviceId;
    late SettingsController settings;
    late TaskRepository taskRepo;
    late DeviceRepository deviceRepo;
    late SyncController syncController;

    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      settings = await SettingsController.load();
      db = await AppDatabase.open(path: inMemoryDatabasePath);
      deviceId = await AppDatabase.deviceId(db);
      taskRepo = TaskRepository(db, deviceId);
      deviceRepo = DeviceRepository(db);
      syncController = SyncController(taskRepo: taskRepo, deviceRepo: deviceRepo);
      await syncController.init();
    });

    addTearDown(() async => await db.close());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider(create: (_) => TaskController(taskRepo, settings)),
          ChangeNotifierProvider.value(value: syncController),
        ],
        child: const MaterialApp(
          home: DevicesPage(),
        ),
      ),
    );

    await tester.pump();

    // Verify local device card
    expect(find.text('Devices & Sync'), findsOneWidget);
    expect(find.text('Local Wi-Fi Sync Active'), findsOneWidget);
    expect(find.text('Show Pairing Code'), findsOneWidget);
    expect(find.text('No Paired Devices'), findsOneWidget);

    // Tap Show Pairing Code
    await tester.tap(find.text('Show Pairing Code'));
    await tester.pumpAndSettle();

    // Verify modal appeared with 6-digit code
    expect(find.text('Pairing Confirmation Code'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Dismiss modal
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Pairing Confirmation Code'), findsNothing);

    // Save a paired device and verify tile appears
    final paired = Device(
      id: 'phone-test',
      name: 'Pixel Test Phone',
      fingerprint: 'fp-123',
      ipAddress: '192.168.1.88',
      port: 43884,
      pairedAt: DateTime.now(),
      trusted: true,
    );
    await deviceRepo.save(paired);
    await syncController.refreshDevices();
    await tester.pumpAndSettle();

    expect(find.text('Pixel Test Phone'), findsOneWidget);
    expect(find.text('192.168.1.88:43884'), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsWidgets);
  });
}
