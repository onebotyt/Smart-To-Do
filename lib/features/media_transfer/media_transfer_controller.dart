import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:synctask/data/models/device.dart';
import 'package:synctask/features/media_transfer/models/media_transfer.dart';
import 'package:synctask/features/sync/transport/sync_engine.dart';

class MediaTransferController extends ChangeNotifier {
  final SyncEngine _syncEngine;
  final List<MediaTransferItem> _transfers = [];

  void Function(String message, {bool isError})? onNotification;

  MediaTransferController({
    required SyncEngine syncEngine,
  }) : _syncEngine = syncEngine {
    _initEngineCallbacks();
  }

  List<MediaTransferItem> get transfers => List.unmodifiable(_transfers);

  bool get hasActiveTransfers =>
      _transfers.any((t) => t.status == MediaTransferStatus.transferring);

  int get activeCount =>
      _transfers.where((t) => t.status == MediaTransferStatus.transferring).length;

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
        _transfers[index].status = MediaTransferStatus.completed;
        _transfers[index].bytesTransferred = _transfers[index].fileSize;
        _transfers[index].filePath = file.path;
        notifyListeners();
        onNotification?.call('Received "${_transfers[index].fileName}" from $senderName');
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

  Future<int> pickAndSendFiles(Device device) async {
    if (device.ipAddress == null || device.ipAddress!.isEmpty) {
      onNotification?.call('Device IP is unknown. Ensure both devices are connected.', isError: true);
      return 0;
    }

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (files.isEmpty) {
        return 0;
      }

      int sentCount = 0;

      for (final pickedFile in files) {
        final filePath = pickedFile.path;
        if (filePath == null) continue;

        final file = File(filePath);
        if (!file.existsSync()) continue;

        final fileName = path.basename(filePath);
        final fileSize = file.lengthSync();
        final transferId = '${DateTime.now().microsecondsSinceEpoch}_${fileName.hashCode}';

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

        try {
          final success = await _syncEngine.sendFileToPeer(
            device: device,
            file: file,
            transferId: transferId,
            onProgress: (bytesSent, total) {
              final idx = _transfers.indexWhere((t) => t.id == transferId);
              if (idx != -1) {
                _transfers[idx].bytesTransferred = bytesSent;
                notifyListeners();
              }
            },
          );

          final idx = _transfers.indexWhere((t) => t.id == transferId);
          if (idx != -1) {
            if (success) {
              _transfers[idx].status = MediaTransferStatus.completed;
              _transfers[idx].bytesTransferred = fileSize;
              sentCount++;
              onNotification?.call('Sent "$fileName" to ${device.name}');
            } else {
              _transfers[idx].status = MediaTransferStatus.failed;
              _transfers[idx].errorMessage = 'Transfer timed out or peer rejected file';
              onNotification?.call('Failed to send "$fileName" to ${device.name}', isError: true);
            }
            notifyListeners();
          }
        } catch (e) {
          final idx = _transfers.indexWhere((t) => t.id == transferId);
          if (idx != -1) {
            _transfers[idx].status = MediaTransferStatus.failed;
            _transfers[idx].errorMessage = e.toString();
            notifyListeners();
          }
          onNotification?.call('Error sending "$fileName": $e', isError: true);
        }
      }

      return sentCount;
    } catch (e) {
      onNotification?.call('File picker error: $e', isError: true);
      return 0;
    }
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

  void removeTransfer(String id) {
    _transfers.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void clearHistory() {
    _transfers.removeWhere(
      (t) =>
          t.status == MediaTransferStatus.completed ||
          t.status == MediaTransferStatus.failed ||
          t.status == MediaTransferStatus.cancelled,
    );
    notifyListeners();
  }
}
