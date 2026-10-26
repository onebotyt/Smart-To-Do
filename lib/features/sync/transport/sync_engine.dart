import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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
  }) async {
    Socket? socket;
    try {
      final localDeviceId = await _deviceRepo.getLocalDeviceId();
      final localDeviceName = await _deviceRepo.getLocalDeviceName();
      final fingerprint = sha256.convert(utf8.encode('$localDeviceId:$pin')).toString();

      socket = await Socket.connect(host, port, timeout: const Duration(seconds: 12));

      final requestMsg = SyncMessage.pairRequest(
        senderId: localDeviceId,
        deviceName: localDeviceName,
        pairingCode: pin,
        fingerprint: fingerprint,
      );

      _sendMsg(socket, requestMsg);

      final lineStream = utf8.decoder.bind(socket).transform(const LineSplitter());
      await for (final line in lineStream.timeout(const Duration(seconds: 12))) {
        if (line.trim().isEmpty) continue;
        final response = SyncMessage.fromJson(line);

        if (response.type == SyncMessageType.pairAccept) {
          final peerName = response.payload['name'] as String? ?? 'SyncTask Peer';
          final peerFingerprint = response.payload['fingerprint'] as String? ?? '';

          final pairedDevice = Device(
            id: response.senderId,
            name: peerName,
            fingerprint: peerFingerprint,
            ipAddress: host,
            port: port,
            pairedAt: DateTime.now(),
            lastSeen: DateTime.now(),
            trusted: true,
          );

          await _deviceRepo.save(pairedDevice);
          return PairResult(success: true, device: pairedDevice);
        } else if (response.type == SyncMessageType.pairReject) {
          final reason = response.payload['reason'] as String? ?? 'Pairing rejected';
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
      return PairResult(
        success: false,
        error: 'Cannot connect to $host:$port (${e.message}). Make sure both devices are on the same Wi-Fi and firewall allows port 43884.',
      );
    } on TimeoutException {
      return PairResult(
        success: false,
        error: 'Connection to $host:$port timed out. Check your Wi-Fi or firewall settings.',
      );
    } catch (e) {
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
          for (final raw in tasksRaw) {
            if (raw is Map<String, dynamic>) {
              final remoteTask = Task.fromMap(raw);
              await _taskRepo.applyRemoteTask(remoteTask);
              changesReceivedCount++;
            }
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
      _sendMsg(socket, SyncMessage.pairReject(
        senderId: localDeviceId,
        reason: 'Invalid or expired pairing code',
      ));
      await socket.close();
      return;
    }

    // Save as paired and trusted
    final newDevice = Device(
      id: msg.senderId,
      name: peerName,
      fingerprint: peerFingerprint,
      ipAddress: socket.remoteAddress.address,
      port: 43884,
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
    ));
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

    for (final raw in tasksRaw) {
      if (raw is Map<String, dynamic>) {
        final remoteTask = Task.fromMap(raw);
        await _taskRepo.applyRemoteTask(remoteTask);
      }
    }

    // Mark changes synced
    await _taskRepo.markChangesSynced();

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

  void dispose() {
    stop();
    _statusController.close();
  }
}
