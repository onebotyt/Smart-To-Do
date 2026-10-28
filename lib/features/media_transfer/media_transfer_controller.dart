import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:synctask/data/models/device.dart';
import 'package:synctask/features/media_transfer/media_storage_helper.dart';
import 'package:synctask/features/media_transfer/models/media_transfer.dart';
import 'package:synctask/features/sync/transport/sync_engine.dart';
import 'package:synctask/platform/native_media_service.dart';
import 'package:synctask/platform/window_service.dart';

class MediaTransferController extends ChangeNotifier {
  final SyncEngine _syncEngine;
  final List<MediaTransferItem> _transfers = [];
  final List<MediaTransferItem> _recentReceived = [];
  final StreamController<MediaTransferItem> _mediaReceivedStream =
      StreamController<MediaTransferItem>.broadcast();

  void Function(String message, {bool isError})? onNotification;

  MediaTransferController({
    required SyncEngine syncEngine,
  }) : _syncEngine = syncEngine {
    _initEngineCallbacks();
  }

  SyncEngine get syncEngine => _syncEngine;

  List<MediaTransferItem> get transfers => List.unmodifiable(_transfers);
  List<MediaTransferItem> get recentReceived => List.unmodifiable(_recentReceived);
  Stream<MediaTransferItem> get onMediaReceived => _mediaReceivedStream.stream;

  bool get hasActiveTransfers =>
      _transfers.any((t) => t.status == MediaTransferStatus.transferring);

  int get activeCount =>
      _transfers.where((t) => t.status == MediaTransferStatus.transferring).length;

  void dismissRecentMedia() {
    _recentReceived.clear();
    notifyListeners();
  }

  void _initEngineCallbacks() {
    _syncEngine.onFileTransferStarted = (
      String transferId,
      String fileName,
      int fileSize,
      String senderId,
      String senderName,
    ) {
      final item = MediaTransferItem(
        id: transferId,
        fileName: fileName,
        filePath: '',
        fileSize: fileSize,
        senderId: senderId,
        senderName: senderName,
        receiverId: 'local',
        receiverName: 'This Device',
        isOutgoing: false,
        status: MediaTransferStatus.transferring,
      );
      _transfers.insert(0, item);
      notifyListeners();
      onNotification?.call('Receiving "$fileName" from $senderName...');
    };

    _syncEngine.onFileTransferProgress = (
      String transferId,
      int bytesReceived,
      int totalBytes,
    ) {
      final index = _transfers.indexWhere((t) => t.id == transferId);
      if (index != -1) {
        _transfers[index].bytesTransferred = bytesReceived;
        notifyListeners();
      }
    };

    _syncEngine.onFileTransferCompleted = (
      String transferId,
      File file,
      String senderId,
      String senderName,
    ) {
      final index = _transfers.indexWhere((t) => t.id == transferId);
      if (index != -1) {
        final completedItem = _transfers[index];
        completedItem.status = MediaTransferStatus.completed;
        completedItem.bytesTransferred = completedItem.fileSize;
        completedItem.filePath = file.path;

        _recentReceived.insert(0, completedItem);
        if (_recentReceived.length > 10) {
          _recentReceived.removeLast();
        }
        _mediaReceivedStream.add(completedItem);

        notifyListeners();
        onNotification?.call('Received "${completedItem.fileName}" from $senderName');
        NativeMediaService.notifyMediaReceived(
          title: 'SyncTask File Received',
          message: 'Received "${completedItem.fileName}" from $senderName',
        );
      }
    };

    _syncEngine.onFileTransferFailed = (
      String transferId,
      String error,
    ) {
      final index = _transfers.indexWhere((t) => t.id == transferId);
      if (index != -1) {
        _transfers[index].status = MediaTransferStatus.failed;
        _transfers[index].errorMessage = error;
        notifyListeners();
        onNotification?.call('Transfer failed: $error', isError: true);
      }
    };
  }

  Future<bool> sendSingleFile(Device device, File file) async {
    if (device.ipAddress == null || device.ipAddress!.isEmpty) {
      onNotification?.call('Device IP is unknown.', isError: true);
      return false;
    }
    if (!file.existsSync()) {
      onNotification?.call('File does not exist: ${file.path}', isError: true);
      return false;
    }

    final transferId = 'transfer-${DateTime.now().millisecondsSinceEpoch}';
    final fileName = path.basename(file.path);
    final fileSize = file.lengthSync();

    final item = MediaTransferItem(
      id: transferId,
      fileName: fileName,
      filePath: file.path,
      fileSize: fileSize,
      senderId: 'local',
      senderName: 'This Device',
      receiverId: device.id,
      receiverName: device.name,
      isOutgoing: true,
      status: MediaTransferStatus.transferring,
    );

    _transfers.insert(0, item);
    notifyListeners();

    final success = await _syncEngine.sendFileToPeer(
      device: device,
      file: file,
      transferId: transferId,
    );

    final idx = _transfers.indexWhere((t) => t.id == transferId);
    if (idx != -1) {
      _transfers[idx].status =
          success ? MediaTransferStatus.completed : MediaTransferStatus.failed;
      if (success) {
        _transfers[idx].bytesTransferred = fileSize;
      }
      notifyListeners();
    }
    return success;
  }

  Future<int> pickAndSendFiles(Device device, {FileType type = FileType.any}) async {
    if (device.ipAddress == null || device.ipAddress!.isEmpty) {
      onNotification?.call('Device IP is unknown. Ensure both devices are connected.', isError: true);
      return 0;
    }

    try {
      if (Platform.isWindows) {
        await PlatformWindowService.setAlwaysOnTop(false);
      }

      final files = await FilePicker.pickFiles(
        type: type,
      );

      if (files.isEmpty) {
        return 0;
      }

      int count = 0;
      for (final pFile in files) {
        final filePath = pFile.path;
        if (filePath == null) continue;

        final localFile = File(filePath);
        if (!localFile.existsSync()) continue;

        final transferId = 'transfer-${DateTime.now().millisecondsSinceEpoch}-$count';
        final fileName = pFile.name;
        final fileSize = localFile.lengthSync();

        final item = MediaTransferItem(
          id: transferId,
          fileName: fileName,
          filePath: filePath,
          fileSize: fileSize,
          senderId: 'local',
          senderName: 'This Device',
          receiverId: device.id,
          receiverName: device.name,
          isOutgoing: true,
          status: MediaTransferStatus.transferring,
        );

        _transfers.insert(0, item);
        notifyListeners();

        final success = await _syncEngine.sendFileToPeer(
          device: device,
          file: localFile,
          transferId: transferId,
        );

        final idx = _transfers.indexWhere((t) => t.id == transferId);
        if (idx != -1) {
          _transfers[idx].status =
              success ? MediaTransferStatus.completed : MediaTransferStatus.failed;
          if (success) {
            _transfers[idx].bytesTransferred = fileSize;
            count++;
          }
          notifyListeners();
        }
      }

      if (count > 0) {
        onNotification?.call('Sent $count file(s) to ${device.name}');
      }
      return count;
    } catch (e) {
      onNotification?.call('File picker error: $e', isError: true);
      return 0;
    }
  }

  Future<int> sendFilesViaQuickShare({
    required String host,
    required int port,
    required String token,
    required String targetDeviceName,
    required List<File> files,
  }) async {
    int count = 0;
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      if (!file.existsSync()) continue;

      final transferId = 'qs-${DateTime.now().millisecondsSinceEpoch}-$i';
      final fileName = path.basename(file.path);
      final fileSize = file.lengthSync();

      final item = MediaTransferItem(
        id: transferId,
        fileName: fileName,
        filePath: file.path,
        fileSize: fileSize,
        senderId: 'local',
        senderName: 'This Device',
        receiverId: 'quickshare',
        receiverName: targetDeviceName,
        isOutgoing: true,
        status: MediaTransferStatus.transferring,
      );

      _transfers.insert(0, item);
      notifyListeners();

      final ok = await _syncEngine.sendFileViaQuickShare(
        host: host,
        port: port,
        token: token,
        targetDeviceName: targetDeviceName,
        file: file,
        transferId: transferId,
        onProgress: (sent, total) {
          final idx = _transfers.indexWhere((t) => t.id == transferId);
          if (idx != -1) {
            _transfers[idx].bytesTransferred = sent;
            notifyListeners();
          }
        },
      );

      final idx = _transfers.indexWhere((t) => t.id == transferId);
      if (idx != -1) {
        _transfers[idx].status = ok ? MediaTransferStatus.completed : MediaTransferStatus.failed;
        if (ok) {
          _transfers[idx].bytesTransferred = fileSize;
          count++;
        }
        notifyListeners();
      }
    }

    if (count > 0) {
      onNotification?.call('Sent $count file(s) via Quick Share to $targetDeviceName');
    }
    return count;
  }

  Future<OpenResult> openFile(String filePath) async {
    if (filePath.isEmpty || !File(filePath).existsSync()) {
      onNotification?.call('File not found: $filePath', isError: true);
      return OpenResult(
        type: ResultType.fileNotFound,
        message: 'File not found',
      );
    }
    return await OpenFilex.open(filePath);
  }

  Future<bool> shareTransfer(MediaTransferItem item) async {
    if (item.filePath.isEmpty || !File(item.filePath).existsSync()) {
      onNotification?.call('File not found: ${item.filePath}', isError: true);
      return false;
    }
    if (Platform.isAndroid) {
      return await NativeMediaService.shareFile(filePath: item.filePath);
    } else {
      await OpenFilex.open(item.filePath);
      return true;
    }
  }

  void removeTransfer(String id) {
    _transfers.removeWhere((t) => t.id == id);
    _recentReceived.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> openMediaFolder() async {
    try {
      final dir = await getMediaSaveDirectory();
      await OpenFilex.open(dir.path);
    } catch (e) {
      onNotification?.call('Failed to open media directory: $e', isError: true);
    }
  }

  void clearHistory() {
    _transfers.removeWhere(
      (t) =>
          t.status == MediaTransferStatus.completed ||
          t.status == MediaTransferStatus.failed ||
          t.status == MediaTransferStatus.cancelled,
    );
    _recentReceived.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _mediaReceivedStream.close();
    super.dispose();
  }
}
