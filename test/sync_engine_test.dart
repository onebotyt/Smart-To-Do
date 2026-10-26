import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synctask/data/database/app_database.dart';
import 'package:synctask/data/repositories/device_repository.dart';
import 'package:synctask/data/repositories/task_repository.dart';
import 'package:synctask/features/sync/transport/sync_engine.dart';

void main() {
  late Directory tempDirA;
  late Directory tempDirB;
  late Database dbA;
  late Database dbB;
  late TaskRepository taskRepoA;
  late TaskRepository taskRepoB;
  late DeviceRepository deviceRepoA;
  late DeviceRepository deviceRepoB;
  late SyncEngine engineA;
  late SyncEngine engineB;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDirA = Directory.systemTemp.createTempSync('synctask_test_a_');
    tempDirB = Directory.systemTemp.createTempSync('synctask_test_b_');

    dbA = await AppDatabase.open(path: '${tempDirA.path}/a.db');
    dbB = await AppDatabase.open(path: '${tempDirB.path}/b.db');

    final deviceIdA = await AppDatabase.deviceId(dbA);
    final deviceIdB = await AppDatabase.deviceId(dbB);

    taskRepoA = TaskRepository(dbA, deviceIdA);
    taskRepoB = TaskRepository(dbB, deviceIdB);

    deviceRepoA = DeviceRepository(dbA);
    deviceRepoB = DeviceRepository(dbB);

    await deviceRepoA.setLocalDeviceName('Desktop A');
    await deviceRepoB.setLocalDeviceName('Phone B');

    // Start Engine A on port 0 (OS chooses available port)
    engineA = SyncEngine(
      taskRepo: taskRepoA,
      deviceRepo: deviceRepoA,
      listenPort: 0,
    );
    await engineA.start();

    // Start Engine B on port 0
    engineB = SyncEngine(
      taskRepo: taskRepoB,
      deviceRepo: deviceRepoB,
      listenPort: 0,
    );
    await engineB.start();
  });

  tearDown(() async {
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

  test('P2P Pairing: rejects incorrect PIN and succeeds with correct PIN', () async {
    final pin = engineA.generatePairingPin();
    final portA = engineA.actualPort!;

    // 1. Attempt with incorrect PIN
    final failResult = await engineB.pairWithPeer(
      host: '127.0.0.1',
      port: portA,
      pin: '000000',
    );
    expect(failResult.success, isFalse);
    expect(failResult.error, contains('Invalid or expired'));

    // 2. Attempt with correct PIN
    final successResult = await engineB.pairWithPeer(
      host: '127.0.0.1',
      port: portA,
      pin: pin,
    );
    expect(successResult.success, isTrue);
    expect(successResult.device, isNotNull);
    expect(successResult.device!.name, 'Desktop A');

    // Verify both A and B have each other saved as trusted
    final deviceIdA = await deviceRepoA.getLocalDeviceId();
    final deviceIdB = await deviceRepoB.getLocalDeviceId();

    final bInA = await deviceRepoA.getById(deviceIdB);
    final aInB = await deviceRepoB.getById(deviceIdA);

    expect(bInA, isNotNull);
    expect(bInA!.trusted, isTrue);
    expect(bInA.name, 'Phone B');

    expect(aInB, isNotNull);
    expect(aInB!.trusted, isTrue);
    expect(aInB.name, 'Desktop A');
  });

  test('Bidirectional sync propagates new tasks, updates, and tombstones', () async {
    final pin = engineA.generatePairingPin();
    final portA = engineA.actualPort!;

    // Pair B with A
    final pairRes = await engineB.pairWithPeer(
      host: '127.0.0.1',
      port: portA,
      pin: pin,
    );
    expect(pairRes.success, isTrue);
    final peerA = pairRes.device!;

    // 1. Create tasks on A
    final task1 = await taskRepoA.create(
      title: 'Buy Groceries',
      notes: 'Apples, Milk',
      priority: 2,
    );
    final task2 = await taskRepoA.create(
      title: 'Code Review',
      notes: 'Milestone 3 sync engine',
    );

    // Initial check: B has 0 tasks
    expect((await taskRepoB.getAll()).length, 0);

    // 2. B syncs with A
    final syncRes1 = await engineB.syncWithDevice(peerA);
    expect(syncRes1.success, isTrue);

    // B should now have both tasks!
    final tasksOnB = await taskRepoB.getAll();
    expect(tasksOnB.length, 2);
    expect(tasksOnB.any((t) => t.id == task1.id && t.title == 'Buy Groceries'), isTrue);
    expect(tasksOnB.any((t) => t.id == task2.id && t.title == 'Code Review'), isTrue);

    // 3. B updates Task 1 to completed, and creates Task 3
    final task1OnB = tasksOnB.firstWhere((t) => t.id == task1.id);
    await taskRepoB.update(task1OnB.copyWith(completed: true));

    final task3 = await taskRepoB.create(
      title: 'Deploy Production',
      priority: 1,
    );

    // 4. B syncs again with A
    final syncRes2 = await engineB.syncWithDevice(peerA);
    expect(syncRes2.success, isTrue);

    // Verify A received updates from B
    final task1OnA = await taskRepoA.getById(task1.id);
    expect(task1OnA!.completed, isTrue);

    final task3OnA = await taskRepoA.getById(task3.id);
    expect(task3OnA, isNotNull);
    expect(task3OnA!.title, 'Deploy Production');

    // 5. Delete Task 2 on A (soft tombstone)
    await taskRepoA.delete(task2.id);
    expect((await taskRepoA.getAll()).any((t) => t.id == task2.id), isFalse);

    // B syncs with A
    final syncRes3 = await engineB.syncWithDevice(peerA);
    expect(syncRes3.success, isTrue);

    // Verify Task 2 is tombstoned/deleted on B
    expect((await taskRepoB.getAll()).any((t) => t.id == task2.id), isFalse);
    final task2OnB = await taskRepoB.getById(task2.id);
    expect(task2OnB!.deleted, isTrue);
  });

  test('Security: revoked device is immediately rejected and access denied', () async {
    final pin = engineA.generatePairingPin();
    final portA = engineA.actualPort!;

    // Pair B with A
    final pairRes = await engineB.pairWithPeer(
      host: '127.0.0.1',
      port: portA,
      pin: pin,
    );
    expect(pairRes.success, isTrue);
    final peerA = pairRes.device!;

    // A revokes B
    final deviceIdB = await deviceRepoB.getLocalDeviceId();
    await deviceRepoA.setTrust(deviceIdB, false);

    // B attempts to sync with A -> must be rejected
    final syncRes = await engineB.syncWithDevice(peerA);
    expect(syncRes.success, isFalse);
    expect(syncRes.error, contains('AUTH_FAILED'));
  });

  test('Conflict resolution logs overridden values during concurrent edits', () async {
    final pin = engineA.generatePairingPin();
    final portA = engineA.actualPort!;

    // Pair B with A
    final pairRes = await engineB.pairWithPeer(
      host: '127.0.0.1',
      port: portA,
      pin: pin,
    );
    expect(pairRes.success, isTrue);
    final peerA = pairRes.device!;

    // 1. Create a base task on A and sync to B
    final baseTask = await taskRepoA.create(
      title: 'Shared Meeting Agenda',
      notes: 'Initial notes',
    );
    await engineB.syncWithDevice(peerA);

    // 2. Simulate concurrent edits:
    // A edits title earlier
    final taskA = (await taskRepoA.getById(baseTask.id))!.copyWith(
      title: 'Title edited on A',
    );
    await taskRepoA.update(taskA);

    // Ensure system clock advances slightly for deterministic LWW test
    await Future.delayed(const Duration(milliseconds: 15));

    // B edits title slightly later
    final taskB = (await taskRepoB.getById(baseTask.id))!.copyWith(
      title: 'Title edited on B',
    );
    await taskRepoB.update(taskB);

    // 3. Sync B with A
    final syncRes = await engineB.syncWithDevice(peerA);
    expect(syncRes.success, isTrue);

    // Verify winner on both sides (LWW: B wins because t2 > t1)
    final finalOnA = await taskRepoA.getById(baseTask.id);
    final finalOnB = await taskRepoB.getById(baseTask.id);

    expect(finalOnA!.title, 'Title edited on B');
    expect(finalOnB!.title, 'Title edited on B');

    // Verify conflict entry was logged on A
    final conflictsOnA = await taskRepoA.getConflicts(taskId: baseTask.id);
    expect(conflictsOnA.isNotEmpty, isTrue);
    expect(conflictsOnA.first.field, 'title');
  });
}
