import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synctask/core/logger/app_logger.dart';
import 'package:synctask/data/database/app_database.dart';
import 'package:synctask/data/repositories/device_repository.dart';
import 'package:synctask/data/repositories/task_repository.dart';
import 'package:synctask/features/sync/sync_controller.dart';
import 'package:synctask/features/sync/transport/sync_engine.dart';
import 'package:synctask/platform/native_network_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('AppLogger Unit Tests', () {
    setUp(() {
      AppLogger().clear();
    });

    test('Records and formats log entries correctly', () {
      expect(AppLogger().logs, isEmpty);

      AppLogger.info('sync', 'Syncing 5 tasks');
      AppLogger.warning('network', 'Slow socket response', {'timeout': 5000});
      AppLogger.error('pairing', 'PIN expired', Exception('Invalid PIN'));

      expect(AppLogger().logs.length, 3);

      final infoLog = AppLogger().logs[0];
      expect(infoLog.level, LogLevel.info);
      expect(infoLog.category, 'sync');
      expect(infoLog.message, 'Syncing 5 tasks');
      expect(infoLog.toString(), contains('[INFO][sync] Syncing 5 tasks'));

      final warnLog = AppLogger().logs[1];
      expect(warnLog.level, LogLevel.warning);
      expect(warnLog.toString(), contains('timeout'));

      final errLog = AppLogger().logs[2];
      expect(errLog.level, LogLevel.error);
      expect(errLog.toString(), contains('Exception: Invalid PIN'));
    });

    test('Generates comprehensive Markdown report for GitHub Issue', () {
      AppLogger.info('system', 'App boot completed');
      AppLogger.info('pairing', 'Paired with Pixel 8');

      final report = AppLogger().generateMarkdownReport(
        deviceId: 'dev-12345',
        deviceName: 'Desktop-Work',
        detectedIps: ['192.168.1.100', '192.168.44.1'],
        pairedDevicesCount: 1,
      );

      expect(report, contains('### SyncTask Diagnostic & Action Report'));
      expect(report, contains('dev-12345'));
      expect(report, contains('Desktop-Work'));
      expect(report, contains('192.168.1.100, 192.168.44.1'));
      expect(report, contains('App boot completed'));
      expect(report, contains('Paired with Pixel 8'));
      expect(report, contains('```log'));
    });

    test('Log buffer caps at maxMemoryLogs and clear empties buffer', () {
      for (int i = 0; i < AppLogger.maxMemoryLogs + 50; i++) {
        AppLogger.debug('test', 'Event $i');
      }

      expect(AppLogger().logs.length, AppLogger.maxMemoryLogs);
      expect(AppLogger().logs.last.message, 'Event ${AppLogger.maxMemoryLogs + 49}');

      AppLogger().clear();
      expect(AppLogger().logs, isEmpty);
    });
  });

  group('Pairing & Device Instant Refresh Integration', () {
    late Directory tempDirA;
    late Directory tempDirB;
    late Database dbA;
    late Database dbB;
    late SyncEngine engineA;
    late SyncEngine engineB;
    late TaskRepository taskRepoA;
    late TaskRepository taskRepoB;
    late DeviceRepository deviceRepoA;
    late DeviceRepository deviceRepoB;
    late SyncController controllerA;

    setUp(() async {
      tempDirA = Directory.systemTemp.createTempSync('pair_test_a_');
      tempDirB = Directory.systemTemp.createTempSync('pair_test_b_');

      dbA = await AppDatabase.open(path: '${tempDirA.path}/a.db');
      dbB = await AppDatabase.open(path: '${tempDirB.path}/b.db');

      final deviceIdA = await AppDatabase.deviceId(dbA);
      final deviceIdB = await AppDatabase.deviceId(dbB);

      taskRepoA = TaskRepository(dbA, deviceIdA);
      taskRepoB = TaskRepository(dbB, deviceIdB);

      deviceRepoA = DeviceRepository(dbA);
      deviceRepoB = DeviceRepository(dbB);

      await deviceRepoA.setLocalDeviceName('Host PC');
      await deviceRepoB.setLocalDeviceName('Mobile Phone');

      engineA = SyncEngine(taskRepo: taskRepoA, deviceRepo: deviceRepoA, listenPort: 0);
      engineB = SyncEngine(taskRepo: taskRepoB, deviceRepo: deviceRepoB, listenPort: 0);

      await engineA.start();
      await engineB.start();

      controllerA = SyncController(
        taskRepo: taskRepoA,
        deviceRepo: deviceRepoA,
        engine: engineA,
      );
      await controllerA.init();
    });

    tearDown(() async {
      controllerA.dispose();
      await engineA.stop();
      await engineB.stop();
      await dbA.close();
      await dbB.close();
      try { tempDirA.deleteSync(recursive: true); } catch (_) {}
      try { tempDirB.deleteSync(recursive: true); } catch (_) {}
    });

    test('Host PC controller immediately displays Mobile Phone when phone pairs', () async {
      // Initially, Host PC has 0 devices
      expect(controllerA.devices, isEmpty);

      // Mobile Phone pairs with Host PC
      final pin = controllerA.startPairingMode();
      expect(controllerA.activePairingPin, isNotNull);

      // Phone executes pairWithPeer to Host PC
      final pairResult = await engineB.pairWithPeer(
        host: '127.0.0.1',
        port: engineA.actualPort!,
        pin: pin,
      );

      expect(pairResult.success, isTrue);
      expect(pairResult.device?.name, 'Host PC');

      // Allow async event delivery and refreshDevices to execute on PC
      await Future.delayed(const Duration(milliseconds: 150));

      // CRITICAL FIX: Host PC MUST now show Mobile Phone in controllerA.devices without restarting app!
      expect(controllerA.devices.isNotEmpty, isTrue);
      final pairedPhone = controllerA.devices.first;
      expect(pairedPhone.name, 'Mobile Phone');
      expect(pairedPhone.trusted, isTrue);
      expect(pairedPhone.port, engineB.actualPort!);
    });
  });

  group('NativeNetworkService Unit Tests', () {
    test('isBluetoothEnabled returns safely without crashing', () async {
      final isEnabled = await NativeNetworkService.isBluetoothEnabled();
      expect(isEnabled, isA<bool>());
    });
  });
}
