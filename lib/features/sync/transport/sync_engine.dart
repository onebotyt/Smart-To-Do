import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:synctask/core/logger/app_logger.dart';
import 'package:synctask/features/media_transfer/media_storage_helper.dart';
import 'package:synctask/data/models/device.dart';
import 'package:synctask/data/models/task.dart';
import 'package:synctask/data/repositories/device_repository.dart';
import 'package:synctask/data/repositories/task_repository.dart';
import 'package:synctask/features/sync/models/sync_message.dart';

class SyncResult {
  final bool success;
  final int changesSent;
  final int changesReceived;
  final String? error;

  const SyncResult({
    required this.success,
    this.changesSent = 0,
    this.changesReceived = 0,
    this.error,
  });
}

class PairResult {
  final bool success;
  final Device? device;
  final String? error;

  const PairResult({
    required this.success,
    this.device,
    this.error,
  });
}

/// Core peer-to-peer TCP synchronization engine.
class SyncEngine {
  final TaskRepository _taskRepo;
  final DeviceRepository _deviceRepo;
  final int listenPort;

  ServerSocket? _serverSocket;
  bool _isListening = false;

  // Active pairing PIN and expiry
  String? _activePairingPin;
  DateTime? _pairingPinExpiry;

  // Replay protection: processed message IDs
  final Set<String> _processedMessageIds = {};

  // Status callbacks
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  /// Callback when verified clipboard text is received from a trusted peer.
  void Function(String text, String senderId)? onClipboardReceived;

  /// Callback when tasks are received and applied from a peer.
  void Function()? onTasksReceived;
  void Function(List<Task> tasks)? onRemoteTasksApplied;

  /// Callback when a new device is paired and trusted (incoming or outgoing).
  void Function(Device device)? onDevicePaired;

  /// Callbacks for direct peer-to-peer media and file transfers.
  void Function(String transferId, String fileName, int fileSize, String senderId, String senderName)?
      onFileTransferStarted;
  void Function(String transferId, int bytesReceived, int totalBytes)?
      onFileTransferProgress;
  void Function(String transferId, File file, String senderId, String senderName)?
      onFileTransferCompleted;
  void Function(String transferId, String error)?
      onFileTransferFailed;

  final Map<String, _InboundFileState> _inboundTransfers = {};

  SyncEngine({
    required TaskRepository taskRepo,
    required DeviceRepository deviceRepo,
    this.listenPort = 43884,
  })  : _taskRepo = taskRepo,
        _deviceRepo = deviceRepo;

  bool get isListening => _isListening;
  int? get actualPort => _serverSocket?.port;

  /// Start the TCP sync server listener.
  Future<void> start() async {
    if (_isListening) return;

    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        listenPort,
        shared: true,
      );
      _isListening = true;
      _serverSocket!.listen(_handleIncomingClient, onError: (e) {
        _statusController.add('Server socket error: $e');
      });
      _statusController.add('Listening on port ${_serverSocket!.port}');
    } catch (e) {
      _statusController.add('Failed to bind server socket: $e');
    }
  }

  /// Stop the TCP sync server listener.
  Future<void> stop() async {
    _isListening = false;
    await _serverSocket?.close();
    _serverSocket = null;
  }

  /// Generate a temporary 6-digit confirmation PIN for pairing.
  String generatePairingPin({Duration validity = const Duration(minutes: 5)}) {
    final rand = (100000 + (DateTime.now().microsecondsSinceEpoch % 900000)).toString();
    _activePairingPin = rand;
    _pairingPinExpiry = DateTime.now().add(validity);
    return rand;
  }

  /// Cancel any active pairing PIN.
  void cancelPairingPin() {
    _activePairingPin = null;
    _pairingPinExpiry = null;
  }

  /// Connect to a remote peer to initiate pairing with a 6-digit PIN code.
  Future<PairResult> pairWithPeer({
    required String host,
    required int port,
    required String pin,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    Socket? socket;
    try {
      final localDeviceId = await _deviceRepo.getLocalDeviceId();
      final localDeviceName = await _deviceRepo.getLocalDeviceName();
      final fingerprint = sha256.convert(utf8.encode('$localDeviceId:$pin')).toString();

      AppLogger.info('pairing', 'Initiating pairing to $host:$port with PIN $pin');
      socket = await Socket.connect(host, port, timeout: timeout);

      final requestMsg = SyncMessage.pairRequest(
        senderId: localDeviceId,
        deviceName: localDeviceName,
        pairingCode: pin,
        fingerprint: fingerprint,
        port: actualPort ?? 43884,
      );

      _sendMsg(socket, requestMsg);

      final lineStream = utf8.decoder.bind(socket).transform(const LineSplitter());
      await for (final line in lineStream.timeout(timeout)) {
        if (line.trim().isEmpty) continue;
        final response = SyncMessage.fromJson(line);

        if (response.type == SyncMessageType.pairAccept) {
          final peerName = response.payload['name'] as String? ?? 'SyncTask Peer';
          final peerFingerprint = response.payload['fingerprint'] as String? ?? '';
          final peerPort = response.payload['port'] as int? ?? port;

          final pairedDevice = Device(
            id: response.senderId,
            name: peerName,
            fingerprint: peerFingerprint,
            ipAddress: host,
            port: peerPort,
            pairedAt: DateTime.now(),
            lastSeen: DateTime.now(),
            trusted: true,
          );

          await _deviceRepo.save(pairedDevice);
          AppLogger.info('pairing', 'Pairing accepted by $peerName ($host:$peerPort)');
          onDevicePaired?.call(pairedDevice);
          return PairResult(success: true, device: pairedDevice);
        } else if (response.type == SyncMessageType.pairReject) {
          final reason = response.payload['reason'] as String? ?? 'Pairing rejected';
          AppLogger.warning('pairing', 'Pairing rejected by peer: $reason');
          return PairResult(success: false, error: reason);
        } else {
          return PairResult(
            success: false,
            error: 'Unexpected response during pairing: ${response.type}',
          );
        }
      }

      return const PairResult(success: false, error: 'Connection closed without response');
    } on SocketException catch (e) {
      AppLogger.error('pairing', 'SocketException connecting to $host:$port: ${e.message}');
      return PairResult(
        success: false,
        error: 'Cannot connect to $host:$port (${e.message}). Make sure both devices are on the same Wi-Fi and firewall allows port 43884.',
      );
    } on TimeoutException {
      AppLogger.error('pairing', 'Connection to $host:$port timed out');
      return PairResult(
        success: false,
        error: 'Connection to $host:$port timed out. Check your Wi-Fi or firewall settings.',
      );
    } catch (e) {
      AppLogger.error('pairing', 'Error pairing with $host:$port', e);
      return PairResult(success: false, error: e.toString());
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  }

  /// Perform bidirectional sync with a paired trusted device.
  Future<SyncResult> syncWithDevice(Device device) async {
    if (!device.trusted) {
      return const SyncResult(
        success: false,
        error: 'Device is untrusted or revoked',
      );
    }

    final host = device.ipAddress;
    if (host == null || host.isEmpty) {
      return const SyncResult(
        success: false,
        error: 'Device IP address is unknown',
      );
    }

    Socket? socket;
    try {
      final localDeviceId = await _deviceRepo.getLocalDeviceId();
      final localDeviceName = await _deviceRepo.getLocalDeviceName();

      socket = await Socket.connect(
        host,
        device.port,
        timeout: const Duration(seconds: 6),
      );

      // 1. Send Hello
      _sendMsg(socket, SyncMessage.hello(
        senderId: localDeviceId,
        deviceName: localDeviceName,
      ));

      // Build local version vector
      final localTasks = await _taskRepo.getAll(includeDeleted: true);
      final localVector = <String, String>{};
      for (final t in localTasks) {
        localVector[t.id] = '${t.revision}:${t.deviceId}';
      }

      int changesSentCount = 0;
      int changesReceivedCount = 0;

      final lines = utf8.decoder.bind(socket).transform(const LineSplitter());

      await for (final line in lines.timeout(const Duration(seconds: 10))) {
        if (line.trim().isEmpty) continue;
        final msg = SyncMessage.fromJson(line);

        if (msg.type == SyncMessageType.error) {
          final errCode = msg.payload['code'] as String? ?? 'ERROR';
          final errMsg = msg.payload['message'] as String? ?? '';
          return SyncResult(success: false, error: '$errCode: $errMsg');
        }

        if (msg.type == SyncMessageType.hello) {
          // 2. Peer replied hello; send our version vector
          _sendMsg(socket, SyncMessage.versionVector(
            senderId: localDeviceId,
            vector: localVector.map((k, v) => MapEntry(k, 0)), // legacy fallback
          )..payload['vvector'] = localVector);
        } else if (msg.type == SyncMessageType.changes) {
          // 3. Inbound delta from server
          final tasksRaw = msg.payload['tasks'] as List<dynamic>? ?? [];
          final appliedTasks = <Task>[];
          for (final raw in tasksRaw) {
            if (raw is Map<String, dynamic>) {
              final remoteTask = Task.fromMap(raw);
              final applied = await _taskRepo.applyRemoteTask(remoteTask);
              appliedTasks.add(applied);
              changesReceivedCount++;
            }
          }
          if (changesReceivedCount > 0) {
            onTasksReceived?.call();
            onRemoteTasksApplied?.call(appliedTasks);
          }
        } else if (msg.type == SyncMessageType.versionVector) {
          // 4. Server sent its version vector; compute client delta for server
          final remoteVector = _parseVector(msg.payload);

          final currentTasks = await _taskRepo.getAll(includeDeleted: true);
          final clientDelta = <Map<String, dynamic>>[];
          for (final t in currentTasks) {
            if (_shouldSendTask(t, remoteVector)) {
              clientDelta.add(t.toMap());
            }
          }

          changesSentCount = clientDelta.length;
          _sendMsg(socket, SyncMessage.changes(
            senderId: localDeviceId,
            tasks: clientDelta,
          ));
        } else if (msg.type == SyncMessageType.ack) {
          // 5. Server acknowledged our changes; sync complete!
          break;
        }
      }

      // Mark local change log entries as synced
      await _taskRepo.markChangesSynced();
      await _deviceRepo.updateLastSeen(device.id);

      return SyncResult(
        success: true,
        changesSent: changesSentCount,
        changesReceived: changesReceivedCount,
      );
    } catch (e) {
      return SyncResult(success: false, error: e.toString());
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  }

  /// Broadcast copied text to all trusted paired devices over local network.
  Future<int> broadcastClipboardText(String text, String hash) async {
    final trusted = await _deviceRepo.getTrustedDevices();
    final localDeviceId = await _deviceRepo.getLocalDeviceId();
    int deliveredCount = 0;

    for (final device in trusted) {
      if (device.ipAddress == null || device.ipAddress!.isEmpty) continue;
      Socket? socket;
      try {
        socket = await Socket.connect(
          device.ipAddress!,
          device.port,
          timeout: const Duration(seconds: 3),
        );
        final msg = SyncMessage.clipboardText(
          senderId: localDeviceId,
          text: text,
          hash: hash,
        );
        _sendMsg(socket, msg);
        deliveredCount++;
      } catch (_) {
        // Silently ignore unreachable peers for real-time clipboard sync
      } finally {
        try {
          await socket?.close();
        } catch (_) {}
      }
    }
    return deliveredCount;
  }

  /// Handle incoming client connection to the server.
  void _handleIncomingClient(Socket socket) {
    final lines = utf8.decoder.bind(socket).transform(const LineSplitter());
    StreamSubscription<String>? sub;

    sub = lines.listen((line) async {
      if (line.trim().isEmpty) return;

      try {
        final msg = SyncMessage.fromJson(line);

        // Replay attack check
        if (_processedMessageIds.contains(msg.id)) {
          return;
        }
        _processedMessageIds.add(msg.id);
        if (_processedMessageIds.length > 2000) {
          _processedMessageIds.remove(_processedMessageIds.first);
        }

        // Handle Pairing Request
        if (msg.type == SyncMessageType.pairRequest) {
          await _handlePairRequest(socket, msg);
          return;
        }

        // For all other messages, verify device trust
        final sender = await _deviceRepo.getById(msg.senderId);
        if (sender == null || !sender.trusted) {
          _sendMsg(socket, SyncMessage.error(
            senderId: await _deviceRepo.getLocalDeviceId(),
            code: 'AUTH_FAILED',
            message: 'Device is not paired or has been revoked',
          ));
          await socket.close();
          return;
        }

        // Update peer network info
        await _deviceRepo.updateLastSeen(
          sender.id,
          ipAddress: socket.remoteAddress.address,
        );

        if (msg.type == SyncMessageType.hello) {
          final localDeviceId = await _deviceRepo.getLocalDeviceId();
          final localDeviceName = await _deviceRepo.getLocalDeviceName();
          _sendMsg(socket, SyncMessage.hello(
            senderId: localDeviceId,
            deviceName: localDeviceName,
          ));
        } else if (msg.type == SyncMessageType.versionVector) {
          await _handleInboundVersionVector(socket, msg);
        } else if (msg.type == SyncMessageType.changes) {
          await _handleInboundChanges(socket, msg);
        } else if (msg.type == SyncMessageType.clipboardText) {
          final text = msg.payload['text'] as String?;
          if (text != null && text.isNotEmpty) {
            onClipboardReceived?.call(text, msg.senderId);
          }
          _sendMsg(socket, SyncMessage.ack(
            senderId: await _deviceRepo.getLocalDeviceId(),
            count: 1,
          ));
        } else if (msg.type == SyncMessageType.ack) {
          await _taskRepo.markChangesSynced();
        } else if (msg.type == SyncMessageType.fileMeta) {
          await _handleInboundFileMeta(socket, msg, sender);
        } else if (msg.type == SyncMessageType.fileChunk) {
          await _handleInboundFileChunk(socket, msg);
        }
      } catch (_) {
        // Discard errors on malformed messages and close
        try {
          await socket.close();
        } catch (_) {}
      }
    }, onError: (_) {
      try {
        socket.close();
      } catch (_) {}
    }, onDone: () {
      sub?.cancel();
    });
  }

  Future<void> _handlePairRequest(Socket socket, SyncMessage msg) async {
    final localDeviceId = await _deviceRepo.getLocalDeviceId();
    final localDeviceName = await _deviceRepo.getLocalDeviceName();

    final pin = msg.payload['pairing_code'] as String?;
    final peerName = msg.payload['name'] as String? ?? 'SyncTask Peer';
    final peerFingerprint = msg.payload['fingerprint'] as String? ?? '';

    final now = DateTime.now();
    final isPinValid = _activePairingPin != null &&
        _pairingPinExpiry != null &&
        now.isBefore(_pairingPinExpiry!) &&
        pin == _activePairingPin;

    if (!isPinValid) {
      AppLogger.warning('pairing', 'Inbound pair request rejected: Invalid or expired PIN $pin from ${socket.remoteAddress.address}');
      _sendMsg(socket, SyncMessage.pairReject(
        senderId: localDeviceId,
        reason: 'Invalid or expired pairing code',
      ));
      await socket.close();
      return;
    }

    // Clean remote IP (remove ::ffff: IPv6 prefix if present)
    var peerIp = socket.remoteAddress.address;
    if (peerIp.startsWith('::ffff:')) {
      peerIp = peerIp.substring(7);
    }
    final peerPort = msg.payload['port'] as int? ??
        (msg.payload['listen_port'] as int?) ??
        43884;

    // Save as paired and trusted
    final newDevice = Device(
      id: msg.senderId,
      name: peerName,
      fingerprint: peerFingerprint,
      ipAddress: peerIp,
      port: peerPort,
      pairedAt: now,
      lastSeen: now,
      trusted: true,
    );

    await _deviceRepo.save(newDevice);
    cancelPairingPin(); // Invalidate PIN after successful pair

    _sendMsg(socket, SyncMessage.pairAccept(
      senderId: localDeviceId,
      deviceName: localDeviceName,
      fingerprint: sha256.convert(utf8.encode('$localDeviceId:$pin')).toString(),
      port: actualPort ?? 43884,
    ));

    AppLogger.info('pairing', 'Accepted inbound pairing from $peerName ($peerIp:$peerPort). Saved to devices.');
    onDevicePaired?.call(newDevice);
  }

  Future<void> _handleInboundVersionVector(Socket socket, SyncMessage msg) async {
    final localDeviceId = await _deviceRepo.getLocalDeviceId();
    final remoteVector = _parseVector(msg.payload);

    final localTasks = await _taskRepo.getAll(includeDeleted: true);
    final localVector = <String, String>{};
    final tasksToSend = <Map<String, dynamic>>[];

    for (final t in localTasks) {
      localVector[t.id] = '${t.revision}:${t.deviceId}';
      if (_shouldSendTask(t, remoteVector)) {
        tasksToSend.add(t.toMap());
      }
    }

    // 1. Send delta changes to client
    _sendMsg(socket, SyncMessage.changes(
      senderId: localDeviceId,
      tasks: tasksToSend,
    ));

    // 2. Send our version vector back to client
    _sendMsg(socket, SyncMessage.versionVector(
      senderId: localDeviceId,
      vector: localVector.map((k, v) => MapEntry(k, 0)),
    )..payload['vvector'] = localVector);
  }

  Map<String, String> _parseVector(Map<String, dynamic> payload) {
    if (payload['vvector'] is Map) {
      final raw = payload['vvector'] as Map;
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    if (payload['vector'] is Map) {
      final raw = payload['vector'] as Map;
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  bool _shouldSendTask(Task t, Map<String, String> remoteVector) {
    final remoteVal = remoteVector[t.id];
    if (remoteVal == null) return true; // Remote missing task

    final parts = remoteVal.split(':');
    final remoteRev = int.tryParse(parts[0]) ?? 0;
    final remoteDev = parts.length > 1 ? parts.sublist(1).join(':') : '';

    if (t.revision > remoteRev) return true;
    if (t.revision == remoteRev && t.deviceId != remoteDev) return true; // Concurrent edit
    return false;
  }

  Future<void> _handleInboundChanges(Socket socket, SyncMessage msg) async {
    final localDeviceId = await _deviceRepo.getLocalDeviceId();
    final tasksRaw = msg.payload['tasks'] as List<dynamic>? ?? [];

    final appliedTasks = <Task>[];
    for (final raw in tasksRaw) {
      if (raw is Map<String, dynamic>) {
        final remoteTask = Task.fromMap(raw);
        final applied = await _taskRepo.applyRemoteTask(remoteTask);
        appliedTasks.add(applied);
      }
    }

    // Mark changes synced
    await _taskRepo.markChangesSynced();
    if (tasksRaw.isNotEmpty) {
      onTasksReceived?.call();
      onRemoteTasksApplied?.call(appliedTasks);
    }

    // Send Ack to conclude the transaction
    _sendMsg(socket, SyncMessage.ack(
      senderId: localDeviceId,
      count: tasksRaw.length,
    ));
  }

  void _sendMsg(Socket socket, SyncMessage msg) {
    try {
      socket.write('${msg.toJson()}\n');
    } catch (_) {}
  }

  Future<void> _handleInboundFileMeta(Socket socket, SyncMessage msg, Device sender) async {
    final transferId = msg.payload['transfer_id'] as String? ?? '';
    try {
      final fileName = msg.payload['file_name'] as String;
      final fileSize = msg.payload['file_size'] as int;
      final checksum = msg.payload['checksum'] as String;
      final totalChunks = msg.payload['total_chunks'] as int;

      AppLogger.info('media', 'Inbound file transfer started: $transferId ($fileSize bytes, $totalChunks chunks) from ${sender.name}');

      final tempDir = Directory.systemTemp;
      final tempFile = File(path.join(tempDir.path, 'synctask_$transferId.tmp'));
      if (tempFile.existsSync()) {
        try { tempFile.deleteSync(); } catch (_) {}
      }
      final sink = tempFile.openWrite(mode: FileMode.write);

      final state = _InboundFileState(
        transferId: transferId,
        fileName: fileName,
        fileSize: fileSize,
        checksum: checksum,
        totalChunks: totalChunks,
        senderId: msg.senderId,
        senderName: sender.name,
        tempFile: tempFile,
        sink: sink,
      );
      _inboundTransfers[transferId] = state;
      onFileTransferStarted?.call(transferId, fileName, fileSize, msg.senderId, sender.name);
    } catch (e, st) {
      AppLogger.error('media', 'Failed to initialize inbound file transfer $transferId: $e', e, st);
      _sendMsg(socket, SyncMessage.fileAck(
        senderId: await _deviceRepo.getLocalDeviceId(),
        transferId: transferId,
        success: false,
        error: 'Failed to initialize file transfer: $e',
      ));
    }
  }

  Future<void> _handleInboundFileChunk(Socket socket, SyncMessage msg) async {
    final transferId = msg.payload['transfer_id'] as String? ?? '';
    final chunkIndex = msg.payload['chunk_index'] as int? ?? 0;
    final totalChunks = msg.payload['total_chunks'] as int? ?? 1;
    final dataBase64 = msg.payload['data'] as String? ?? '';

    final state = _inboundTransfers[transferId];
    if (state == null) {
      AppLogger.warning('media', 'Received chunk for uninitialized transfer $transferId');
      return;
    }

    try {
      final chunkBytes = base64Decode(dataBase64);
      state.sink.add(chunkBytes);
      state.bytesReceived += chunkBytes.length;
      state.receivedChunks++;

      onFileTransferProgress?.call(transferId, state.bytesReceived, state.fileSize);

      if (chunkIndex >= totalChunks - 1 || state.receivedChunks >= totalChunks) {
        await state.sink.flush();
        await state.sink.close();

        final fileBytes = await state.tempFile.readAsBytes();
        final calculatedHash = sha256.convert(fileBytes).toString();

        if (calculatedHash.toLowerCase() == state.checksum.toLowerCase()) {
          final saveDir = await getMediaSaveDirectory();
          final safeName = sanitizeFileName(state.fileName);
          String destPath = path.join(saveDir.path, safeName);

          if (File(destPath).existsSync()) {
            final ext = path.extension(safeName);
            final base = path.basenameWithoutExtension(safeName);
            final ts = DateTime.now().millisecondsSinceEpoch;
            destPath = path.join(saveDir.path, '${base}_$ts$ext');
          }

          final savedFile = await state.tempFile.copy(destPath);
          try { state.tempFile.deleteSync(); } catch (_) {}

          _inboundTransfers.remove(transferId);
          AppLogger.info('media', 'Inbound file $transferId received and verified successfully');

          _sendMsg(socket, SyncMessage.fileAck(
            senderId: await _deviceRepo.getLocalDeviceId(),
            transferId: transferId,
            success: true,
          ));

          onFileTransferCompleted?.call(transferId, savedFile, state.senderId, state.senderName);
        } else {
          AppLogger.error('media', 'Checksum mismatch for transfer $transferId');
          _inboundTransfers.remove(transferId);
          try { state.tempFile.deleteSync(); } catch (_) {}
          _sendMsg(socket, SyncMessage.fileAck(
            senderId: await _deviceRepo.getLocalDeviceId(),
            transferId: transferId,
            success: false,
            error: 'SHA-256 checksum mismatch',
          ));
          onFileTransferFailed?.call(transferId, 'Checksum mismatch');
        }
      }
    } catch (e, st) {
      AppLogger.error('media', 'Error processing chunk for transfer $transferId: $e', e, st);
      try { await state.sink.close(); } catch (_) {}
      try { state.tempFile.deleteSync(); } catch (_) {}
      _inboundTransfers.remove(transferId);

      _sendMsg(socket, SyncMessage.fileAck(
        senderId: await _deviceRepo.getLocalDeviceId(),
        transferId: transferId,
        success: false,
        error: e.toString(),
      ));
      onFileTransferFailed?.call(transferId, e.toString());
    }
  }

  Future<bool> sendFileToPeer({
    required Device device,
    required File file,
    required String transferId,
    Function(int bytesSent, int totalBytes)? onProgress,
  }) async {
    final fileName = path.basename(file.path);
    final fileBytes = await file.readAsBytes();
    final fileSize = fileBytes.length;
    final checksum = sha256.convert(fileBytes).toString();

    final localDeviceId = await _deviceRepo.getLocalDeviceId();
    final localDeviceName = await _deviceRepo.getLocalDeviceName();

    const chunkSize = 64 * 1024;
    final totalChunks = (fileSize / chunkSize).ceil().clamp(1, 999999);

    final host = device.ipAddress;
    if (host == null || host.isEmpty) {
      AppLogger.warning('media', 'Cannot send file: Peer ${device.name} IP is unknown');
      return false;
    }

    AppLogger.info('media', 'Connecting to ${device.name} ($host:${device.port}) to send file ($fileSize bytes, $totalChunks chunks)');

    final socket = await Socket.connect(
      host,
      device.port,
      timeout: const Duration(seconds: 8),
    );

    try {
      final lines = utf8.decoder.bind(socket).transform(const LineSplitter());
      final completer = Completer<bool>();

      final sub = lines.listen((line) {
        if (line.trim().isEmpty) return;
        try {
          final msg = SyncMessage.fromJson(line);
          if (msg.type == SyncMessageType.fileAck) {
            final success = msg.payload['success'] as bool? ?? false;
            final error = msg.payload['error'] as String?;
            if (success) {
              AppLogger.info('media', 'Peer accepted and completed file transfer $transferId');
            } else {
              AppLogger.warning('media', 'Peer rejected file transfer $transferId: $error');
            }
            if (!completer.isCompleted) {
              completer.complete(success);
            }
          } else if (msg.type == SyncMessageType.error) {
            final errCode = msg.payload['code'] as String? ?? 'ERROR';
            final errMsg = msg.payload['message'] as String? ?? '';
            AppLogger.error('media', 'Peer returned error for transfer $transferId: $errCode - $errMsg');
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          }
        } catch (_) {}
      }, onError: (err) {
        AppLogger.error('media', 'Socket stream error during file transfer: $err');
        if (!completer.isCompleted) completer.complete(false);
      }, onDone: () {
        if (!completer.isCompleted) completer.complete(false);
      });

      _sendMsg(socket, SyncMessage.hello(
        senderId: localDeviceId,
        deviceName: localDeviceName,
      ));

      _sendMsg(socket, SyncMessage.fileMeta(
        senderId: localDeviceId,
        transferId: transferId,
        fileName: fileName,
        fileSize: fileSize,
        fileType: path.extension(fileName),
        checksum: checksum,
        totalChunks: totalChunks,
      ));

      await socket.flush();

      int bytesSent = 0;
      for (int i = 0; i < totalChunks; i++) {
        if (completer.isCompleted) {
          // Aborted early by peer rejection/error
          break;
        }

        final start = i * chunkSize;
        final end = (start + chunkSize).clamp(0, fileSize);
        final chunk = fileBytes.sublist(start, end);
        final base64Chunk = base64Encode(chunk);

        _sendMsg(socket, SyncMessage.fileChunk(
          senderId: localDeviceId,
          transferId: transferId,
          chunkIndex: i,
          totalChunks: totalChunks,
          dataBase64: base64Chunk,
        ));

        bytesSent += chunk.length;
        onProgress?.call(bytesSent, fileSize);

        if (i % 4 == 0) {
          await socket.flush();
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      await socket.flush();

      final success = await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          AppLogger.warning('media', 'File transfer $transferId timed out waiting for peer acknowledgement');
          return false;
        },
      );

      await sub.cancel();
      return success;
    } finally {
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  void dispose() {
    stop();
    _statusController.close();
  }
}

class _InboundFileState {
  final String transferId;
  final String fileName;
  final int fileSize;
  final String checksum;
  final int totalChunks;
  final String senderId;
  final String senderName;
  final File tempFile;
  final IOSink sink;
  int receivedChunks = 0;
  int bytesReceived = 0;

  _InboundFileState({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.checksum,
    required this.totalChunks,
    required this.senderId,
    required this.senderName,
    required this.tempFile,
    required this.sink,
  });
}
