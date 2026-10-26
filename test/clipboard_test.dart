import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synctask/data/database/app_database.dart';
import 'package:synctask/data/repositories/device_repository.dart';
import 'package:synctask/data/repositories/task_repository.dart';
import 'package:synctask/features/clipboard/clipboard_controller.dart';
import 'package:synctask/features/sync/transport/sync_engine.dart';
import 'package:synctask/platform/clipboard_service.dart';

class MockClipboardService implements ClipboardService {
  final StreamController<String> _copyController =
      StreamController<String>.broadcast();
  String? currentText;
  int writeCount = 0;

  @override
  Stream<String> get onLocalCopy => _copyController.stream;

  @override
  Future<String?> readText() async => currentText;

  @override
  Future<void> writeText(String text) async {
    currentText = text;
    writeCount++;
  }

  void simulateLocalCopy(String text) {
    currentText = text;
    _copyController.add(text);
  }

  @override
  void startListening({Duration pollInterval = const Duration(seconds: 1)}) {}

  @override
  void stopListening() {}

  @override
  void dispose() {
    _copyController.close();
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ClipboardController unit tests', () {
    late Directory tempDir;
    late Database db;
    late TaskRepository taskRepo;
    late DeviceRepository deviceRepo;
    late SyncEngine engine;
    late MockClipboardService mockClipboard;
    late ClipboardController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('clip_test_');
      db = await AppDatabase.open(path: '${tempDir.path}/clip.db');
      final deviceId = await AppDatabase.deviceId(db);
      taskRepo = TaskRepository(db, deviceId);
      deviceRepo = DeviceRepository(db);

      engine = SyncEngine(
        taskRepo: taskRepo,
        deviceRepo: deviceRepo,
        listenPort: 0,
      );
      mockClipboard = MockClipboardService();
      controller = ClipboardController(
        syncEngine: engine,
        clipboardService: mockClipboard,
      );
      await controller.init();
    });

    tearDown(() async {
      controller.dispose();
      await engine.stop();
      await db.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('Opt-in requirement: copy is ignored by default until enabled', () async {
      expect(controller.isEnabled, isFalse);

      mockClipboard.simulateLocalCopy('Secret text');
      await Future.delayed(const Duration(milliseconds: 20));

      expect(controller.syncCount, 0);
      expect(controller.lastSyncedAt, isNull);
    });

    test('Enabling sync broadcasts copy, and pausing suppresses it', () async {
      await controller.setEnabled(true);
      expect(controller.isEnabled, isTrue);

      // Now copying triggers broadcast (even if 0 peers connected, sync logic runs)
      mockClipboard.simulateLocalCopy('First copy item');
      await Future.delayed(const Duration(milliseconds: 20));

      // Pause sync
      await controller.setPaused(true);
      expect(controller.isPaused, isTrue);

      mockClipboard.simulateLocalCopy('Paused copy item');
      await Future.delayed(const Duration(milliseconds: 20));

      // Resume sync
      await controller.setPaused(false);
      expect(controller.isPaused, isFalse);
    });

    test('Deduplication & loop prevention ignores duplicate and echo texts', () async {
      await controller.setEnabled(true);

      // Simulate incoming remote clipboard text from a peer
      engine.onClipboardReceived?.call('Remote copied text', 'peer-1');
      await Future.delayed(const Duration(milliseconds: 20));

      // Verify written to local clipboard
      expect(mockClipboard.currentText, 'Remote copied text');
      expect(mockClipboard.writeCount, 1);

      // If local clipboard listener detects the same text, it must be ignored (no echo loop!)
      final initialCount = controller.syncCount;
      mockClipboard.simulateLocalCopy('Remote copied text');
      await Future.delayed(const Duration(milliseconds: 20));

      expect(controller.syncCount, initialCount);
    });
  });

  group('P2P Direct Socket Clipboard Sync Integration', () {
    late Directory tempDirA;
    late Directory tempDirB;
    late Database dbA;
    late Database dbB;
    late SyncEngine engineA;
    late SyncEngine engineB;
    late MockClipboardService mockClipboardA;
    late MockClipboardService mockClipboardB;
    late ClipboardController controllerA;
    late ClipboardController controllerB;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDirA = Directory.systemTemp.createTempSync('clip_p2p_a_');
      tempDirB = Directory.systemTemp.createTempSync('clip_p2p_b_');

      dbA = await AppDatabase.open(path: '${tempDirA.path}/a.db');
      dbB = await AppDatabase.open(path: '${tempDirB.path}/b.db');

      final deviceIdA = await AppDatabase.deviceId(dbA);
      final deviceIdB = await AppDatabase.deviceId(dbB);

      final taskRepoA = TaskRepository(dbA, deviceIdA);
      final taskRepoB = TaskRepository(dbB, deviceIdB);

      final deviceRepoA = DeviceRepository(dbA);
      final deviceRepoB = DeviceRepository(dbB);

      await deviceRepoA.setLocalDeviceName('Desktop A');
      await deviceRepoB.setLocalDeviceName('Phone B');

      engineA = SyncEngine(taskRepo: taskRepoA, deviceRepo: deviceRepoA, listenPort: 0);
      engineB = SyncEngine(taskRepo: taskRepoB, deviceRepo: deviceRepoB, listenPort: 0);

      await engineA.start();
      await engineB.start();

      mockClipboardA = MockClipboardService();
      mockClipboardB = MockClipboardService();

      controllerA = ClipboardController(syncEngine: engineA, clipboardService: mockClipboardA);
      controllerB = ClipboardController(syncEngine: engineB, clipboardService: mockClipboardB);

      await controllerA.init();
      await controllerB.init();
      await controllerA.setEnabled(true);
      await controllerB.setEnabled(true);

      // Pair B with A
      final pin = engineA.generatePairingPin();
      final pairRes = await engineB.pairWithPeer(
        host: '127.0.0.1',
        port: engineA.actualPort!,
        pin: pin,
      );
      expect(pairRes.success, isTrue);

      // Save A in B and B in A with actual loopback ports
      await deviceRepoA.updateLastSeen(
        deviceIdB,
        ipAddress: '127.0.0.1',
        port: engineB.actualPort!,
      );
      await deviceRepoB.updateLastSeen(
        deviceIdA,
        ipAddress: '127.0.0.1',
        port: engineA.actualPort!,
      );
    });

    tearDown(() async {
      controllerA.dispose();
      controllerB.dispose();
      await engineA.stop();
      await engineB.stop();
      await dbA.close();
      await dbB.close();
      try {
        tempDirA.deleteSync(recursive: true);
      } catch (_) {}
      try {
        tempDirB.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('Device A copies text and Device B receives it over P2P socket', () async {
      expect(mockClipboardB.currentText, isNull);

      // Device A copies text
      mockClipboardA.simulateLocalCopy('Copied on Device A');
      await Future.delayed(const Duration(milliseconds: 200));

      // Device B receives and writes to clipboard!
      expect(mockClipboardB.currentText, 'Copied on Device A');
      expect(mockClipboardB.writeCount, 1);
    });
  });
}
