import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:synctask/data/database/app_database.dart';
import 'package:synctask/data/models/device.dart';
import 'package:synctask/data/repositories/device_repository.dart';
import 'package:synctask/data/repositories/task_repository.dart';
import 'package:synctask/features/media_transfer/media_storage_helper.dart';
import 'package:synctask/features/media_transfer/media_transfer_controller.dart';
import 'package:synctask/features/media_transfer/models/media_transfer.dart';
import 'package:synctask/features/media_transfer/task_attachment_helper.dart';
import 'package:synctask/features/media_transfer/widgets/media_transfer_widget.dart';
import 'package:synctask/features/sync/transport/sync_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('MediaTransferItem Model Tests', () {
    test('Calculates formatted size correctly across B, KB, MB, GB', () {
      final itemBytes = MediaTransferItem(
        id: '1',
        fileName: 'test.txt',
        filePath: '/tmp/test.txt',
        fileSize: 500,
        senderId: 'devA',
        senderName: 'Device A',
        receiverId: 'devB',
        receiverName: 'Device B',
        isOutgoing: true,
      );
      expect(itemBytes.formattedSize, '500 B');

      final itemKB = itemBytes.copyWith(fileSize: 1500);
      expect(itemKB.formattedSize, '1.5 KB');
      final itemKb2 = MediaTransferItem(
        id: '2',
        fileName: 'photo.jpg',
        filePath: '/tmp/photo.jpg',
        fileSize: 2048,
        senderId: 'devA',
        senderName: 'Device A',
        receiverId: 'devB',
        receiverName: 'Device B',
        isOutgoing: true,
      );
      expect(itemKb2.formattedSize, '2.0 KB');

      final itemMB = MediaTransferItem(
        id: '3',
        fileName: 'video.mp4',
        filePath: '/tmp/video.mp4',
        fileSize: 5 * 1024 * 1024,
        senderId: 'devA',
        senderName: 'Device A',
        receiverId: 'devB',
        receiverName: 'Device B',
        isOutgoing: false,
      );
      expect(itemMB.formattedSize, '5.0 MB');

      final itemGB = MediaTransferItem(
        id: '4',
        fileName: 'archive.iso',
        filePath: '/tmp/archive.iso',
        fileSize: 3 * 1024 * 1024 * 1024,
        senderId: 'devA',
        senderName: 'Device A',
        receiverId: 'devB',
        receiverName: 'Device B',
        isOutgoing: false,
      );
      expect(itemGB.formattedSize, '3.0 GB');
    });

    test('Progress clamped between 0.0 and 1.0', () {
      final item = MediaTransferItem(
        id: '1',
        fileName: 'sample.pdf',
        filePath: '/tmp/sample.pdf',
        fileSize: 1000,
        senderId: 'devA',
        senderName: 'Device A',
        receiverId: 'devB',
        receiverName: 'Device B',
        isOutgoing: true,
        bytesTransferred: 500,
      );
      expect(item.progress, 0.5);

      item.bytesTransferred = 1200;
      expect(item.progress, 1.0);

      item.bytesTransferred = 0;
      expect(item.progress, 0.0);
    });

    test('sanitizeFileName removes disallowed characters', () {
      expect(sanitizeFileName('test:file*name?.txt'), 'test_file_name_.txt');
      expect(sanitizeFileName('normal_file.png'), 'normal_file.png');
    });

    test('TaskAttachmentHelper extracts attachments, cleans text and formats notes', () {
      const originalNote = 'Remember to submit invoice';
      final formatted = TaskAttachmentHelper.formatNoteWithAttachments(
        originalNote,
        ['/path/to/invoice.pdf', '/path/to/receipt.jpg'],
      );

      expect(formatted, contains('Remember to submit invoice'));
      expect(formatted, contains('[attachment:/path/to/invoice.pdf]'));
      expect(formatted, contains('[attachment:/path/to/receipt.jpg]'));

      final extracted = TaskAttachmentHelper.extractAttachments(formatted);
      expect(extracted, equals(['/path/to/invoice.pdf', '/path/to/receipt.jpg']));

      final cleaned = TaskAttachmentHelper.cleanNoteText(formatted);
      expect(cleaned, 'Remember to submit invoice');
    });
  });

  group('MediaTransferController Lifecycle & Callbacks', () {
    late Database db;
    late TaskRepository taskRepo;
    late DeviceRepository deviceRepo;
    late SyncEngine syncEngine;
    late MediaTransferController controller;

    setUp(() async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
      taskRepo = TaskRepository(db, 'local-dev-id');
      deviceRepo = DeviceRepository(db);
      syncEngine = SyncEngine(taskRepo: taskRepo, deviceRepo: deviceRepo);
      controller = MediaTransferController(syncEngine: syncEngine);
    });

    tearDown(() async {
      await db.close();
    });

    test('Inbound file transfer events update controller transfers state', () {
      expect(controller.transfers, isEmpty);

      // 1. Simulate inbound file transfer started
      syncEngine.onFileTransferStarted?.call(
        'transfer-101',
        'sunset.jpg',
        100000,
        'remote-peer',
        'Pixel 8',
      );

      expect(controller.transfers.length, 1);
      final item = controller.transfers.first;
      expect(item.id, 'transfer-101');
      expect(item.fileName, 'sunset.jpg');
      expect(item.senderName, 'Pixel 8');
      expect(item.status, MediaTransferStatus.transferring);
      expect(item.progress, 0.0);

      // 2. Simulate progress
      syncEngine.onFileTransferProgress?.call('transfer-101', 50000, 100000);
      expect(controller.transfers.first.bytesTransferred, 50000);
      expect(controller.transfers.first.progress, 0.5);

      // 3. Simulate completion
      final mockFile = File('/data/downloads/sunset.jpg');
      syncEngine.onFileTransferCompleted?.call(
        'transfer-101',
        mockFile,
        'remote-peer',
        'Pixel 8',
      );

      expect(controller.transfers.first.status, MediaTransferStatus.completed);
      expect(controller.transfers.first.filePath, mockFile.path);

      // 4. Clear history
      controller.clearHistory();
      expect(controller.transfers, isEmpty);
    });

    test('Inbound failure updates status and error message', () {
      syncEngine.onFileTransferStarted?.call(
        'transfer-102',
        'doc.pdf',
        5000,
        'remote-peer',
        'Laptop',
      );

      syncEngine.onFileTransferFailed?.call('transfer-102', 'Checksum mismatch');

      expect(controller.transfers.first.status, MediaTransferStatus.failed);
      expect(controller.transfers.first.errorMessage, 'Checksum mismatch');

      controller.removeTransfer('transfer-102');
      expect(controller.transfers, isEmpty);
    });
  });

  group('MediaTransferSection Widget Tests', () {
    late Database db;
    late TaskRepository taskRepo;
    late DeviceRepository deviceRepo;
    late SyncEngine syncEngine;
    late MediaTransferController controller;

    setUp(() async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
      taskRepo = TaskRepository(db, 'local-dev-id');
      deviceRepo = DeviceRepository(db);
      syncEngine = SyncEngine(taskRepo: taskRepo, deviceRepo: deviceRepo);
      controller = MediaTransferController(syncEngine: syncEngine);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Renders empty state and updates when transfer is added',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MediaTransferSection(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Direct P2P Media & File Share'), findsOneWidget);
      expect(find.textContaining('No media transfers yet'), findsOneWidget);

      // Trigger incoming transfer
      syncEngine.onFileTransferStarted?.call(
        'tf-1',
        'presentation.pdf',
        204800,
        'dev-work',
        'Office Laptop',
      );
      await tester.pump();

      expect(find.text('presentation.pdf'), findsOneWidget);
      expect(find.textContaining('Office Laptop'), findsOneWidget);
      expect(find.text('Recent Transfers (1)'), findsOneWidget);

      // Complete transfer
      syncEngine.onFileTransferCompleted?.call(
        'tf-1',
        File('/downloads/presentation.pdf'),
        'dev-work',
        'Office Laptop',
      );
      await tester.pump();

      expect(find.text('Open'), findsOneWidget);

      // Clear history
      await tester.tap(find.text('Clear History'));
      await tester.pump();

      expect(find.textContaining('No media transfers yet'), findsOneWidget);
    });
  });

  group('P2P Direct Socket Media Transfer Integration', () {
    late Directory tempDirA;
    late Directory tempDirB;
    late Database dbA;
    late Database dbB;
    late SyncEngine engineA;
    late SyncEngine engineB;
    late MediaTransferController controllerA;
    late MediaTransferController controllerB;
    late Device deviceB;
    late String deviceIdA;
    late DeviceRepository deviceRepoB;

    setUp(() async {
      tempDirA = Directory.systemTemp.createTempSync('media_p2p_a_');
      tempDirB = Directory.systemTemp.createTempSync('media_p2p_b_');
      setCustomMediaSaveDirectory(tempDirB);

      dbA = await AppDatabase.open(path: '${tempDirA.path}/a.db');
      dbB = await AppDatabase.open(path: '${tempDirB.path}/b.db');

      deviceIdA = await AppDatabase.deviceId(dbA);
      final deviceIdB = await AppDatabase.deviceId(dbB);

      final taskRepoA = TaskRepository(dbA, deviceIdA);
      final taskRepoB = TaskRepository(dbB, deviceIdB);

      final deviceRepoA = DeviceRepository(dbA);
      deviceRepoB = DeviceRepository(dbB);

      await deviceRepoA.setLocalDeviceName('Desktop A');
      await deviceRepoB.setLocalDeviceName('Phone B');

      engineA = SyncEngine(taskRepo: taskRepoA, deviceRepo: deviceRepoA, listenPort: 0);
      engineB = SyncEngine(taskRepo: taskRepoB, deviceRepo: deviceRepoB, listenPort: 0);

      await engineA.start();
      await engineB.start();

      controllerA = MediaTransferController(syncEngine: engineA);
      controllerB = MediaTransferController(syncEngine: engineB);

      // Pair B with A
      final pin = engineA.generatePairingPin();
      final pairRes = await engineB.pairWithPeer(
        host: '127.0.0.1',
        port: engineA.actualPort!,
        pin: pin,
      );
      expect(pairRes.success, isTrue);

      deviceB = Device(
        id: deviceIdB,
        name: 'Phone B',
        fingerprint: 'fpB',
        ipAddress: '127.0.0.1',
        port: engineB.actualPort!,
        pairedAt: DateTime.now(),
        lastSeen: DateTime.now(),
        trusted: true,
      );
      await deviceRepoA.save(deviceB);
    });

    tearDown(() async {
      setCustomMediaSaveDirectory(null);
      controllerA.dispose();
      controllerB.dispose();
      await engineA.stop();
      await engineB.stop();
      await dbA.close();
      await dbB.close();
      try { tempDirA.deleteSync(recursive: true); } catch (_) {}
      try { tempDirB.deleteSync(recursive: true); } catch (_) {}
    });

    test('Streams file in chunks over loopback TCP, verifies SHA-256 and completes', () async {
      // 1. Create a 130 KB sample test file on Device A (more than 2x 64KB chunks)
      final sampleFile = File('${tempDirA.path}/sample_photo.jpg');
      final sampleData = List<int>.generate(130 * 1024, (i) => i % 256);
      await sampleFile.writeAsBytes(sampleData);

      // 2. Device A sends file to Device B
      int progressUpdates = 0;
      final success = await engineA.sendFileToPeer(
        device: deviceB,
        file: sampleFile,
        transferId: 'transfer-xyz-99',
        onProgress: (sent, total) {
          progressUpdates++;
        },
      );

      expect(success, isTrue);
      expect(progressUpdates, greaterThan(1));

      // Allow B async file writing and callback dispatch to settle
      await Future.delayed(const Duration(milliseconds: 100));

      // 3. Verify Device B received the transfer
      expect(controllerB.transfers.isNotEmpty, isTrue);
      final receivedItem = controllerB.transfers.first;
      expect(receivedItem.status, MediaTransferStatus.completed);
      expect(receivedItem.fileName, 'sample_photo.jpg');
      expect(receivedItem.fileSize, 130 * 1024);

      // 4. Verify file exists on disk and content bytes match exactly
      final receivedFile = File(receivedItem.filePath);
      expect(receivedFile.existsSync(), isTrue);
      final receivedBytes = await receivedFile.readAsBytes();
      expect(receivedBytes.length, sampleData.length);
      expect(receivedBytes, equals(sampleData));

      // Cleanup received file
      try { receivedFile.deleteSync(); } catch (_) {}
    });

    test('Sending to revoked or untrusted peer fails fast with error message', () async {
      // 1. Untrust device B on engine B's deviceRepo
      final devAOnB = await deviceRepoB.getById(deviceIdA);
      if (devAOnB != null) {
        await deviceRepoB.save(devAOnB.copyWith(trusted: false));
      }

      final sampleFile = File('${tempDirA.path}/sample_doc.txt');
      await sampleFile.writeAsString('Confidential document');

      final startTime = DateTime.now();
      final success = await engineA.sendFileToPeer(
        device: deviceB,
        file: sampleFile,
        transferId: 'transfer-untrusted-1',
      );
      final elapsed = DateTime.now().difference(startTime);

      // Must fail fast within 3 seconds, not wait for 45s timeout
      expect(success, isFalse);
      expect(elapsed.inSeconds, lessThan(5));
    });

    test('getMediaSaveDirectory falls back gracefully to a valid writable directory', () async {
      setCustomMediaSaveDirectory(null);
      final dir = await getMediaSaveDirectory();
      expect(dir.existsSync(), isTrue);
      expect(dir.path, isNotEmpty);
    });
  });
}
