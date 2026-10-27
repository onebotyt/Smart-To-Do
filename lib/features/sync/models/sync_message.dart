import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Message types supported by the SyncTask synchronization protocol.
class SyncMessageType {
  static const String pairRequest = 'pair_request';
  static const String pairAccept = 'pair_accept';
  static const String pairReject = 'pair_reject';
  static const String hello = 'hello';
  static const String versionVector = 'version_vector';
  static const String changes = 'changes';
  static const String ack = 'ack';
  static const String error = 'error';
  static const String clipboardText = 'clipboard_text';
  static const String fileMeta = 'file_meta';
  static const String fileChunk = 'file_chunk';
  static const String fileAck = 'file_ack';
}

/// Represents a protocol message exchanged between SyncTask devices.
class SyncMessage {
  static const int currentProtocolVersion = 1;
  static const _uuid = Uuid();

  final String id;
  final int protocolVersion;
  final String type;
  final int counter;
  final String senderId;
  final Map<String, dynamic> payload;

  const SyncMessage({
    required this.id,
    this.protocolVersion = currentProtocolVersion,
    required this.type,
    required this.counter,
    required this.senderId,
    required this.payload,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'protocol_version': protocolVersion,
      'type': type,
      'counter': counter,
      'sender_id': senderId,
      'payload': payload,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory SyncMessage.fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String?;
    final protocolVersion = map['protocol_version'] as int?;
    final type = map['type'] as String?;
    final counter = map['counter'] as int?;
    final senderId = map['sender_id'] as String?;
    final payload = map['payload'] as Map<String, dynamic>?;

    if (id == null || id.isEmpty) {
      throw const FormatException('Missing or invalid "id" field in message');
    }
    if (protocolVersion == null || protocolVersion <= 0) {
      throw const FormatException('Missing or invalid "protocol_version"');
    }
    if (type == null || type.isEmpty) {
      throw const FormatException('Missing or invalid "type" field in message');
    }
    if (counter == null || counter < 0) {
      throw const FormatException('Missing or invalid "counter" field in message');
    }
    if (senderId == null || senderId.isEmpty) {
      throw const FormatException('Missing or invalid "sender_id" field in message');
    }
    if (payload == null) {
      throw const FormatException('Missing or invalid "payload" field in message');
    }

    return SyncMessage(
      id: id,
      protocolVersion: protocolVersion,
      type: type,
      counter: counter,
      senderId: senderId,
      payload: payload,
    );
  }

  factory SyncMessage.fromJson(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Message root must be a JSON object');
    }
    return SyncMessage.fromMap(decoded);
  }

  // Helper factory constructors for protocol messages:

  factory SyncMessage.pairRequest({
    required String senderId,
    required String deviceName,
    required String pairingCode,
    required String fingerprint,
    int counter = 1,
  }) {
    return SyncMessage(
      id: _uuid.v4(),
      type: SyncMessageType.pairRequest,
      counter: counter,
      senderId: senderId,
      payload: {
        'name': deviceName,
        'pairing_code': pairingCode,
        'fingerprint': fingerprint,
      },
    );
  }

  factory SyncMessage.pairAccept({
    required String senderId,
    required String deviceName,
    required String fingerprint,
    int counter = 1,
  }) {
    return SyncMessage(
      id: _uuid.v4(),
      type: SyncMessageType.pairAccept,
      counter: counter,
      senderId: senderId,
      payload: {
        'name': deviceName,
        'fingerprint': fingerprint,
      },
    );
  }

  factory SyncMessage.pairReject({
    required String senderId,
    required String reason,
    int counter = 1,
  }) {
    return SyncMessage(
      id: _uuid.v4(),
      type: SyncMessageType.pairReject,
      counter: counter,
      senderId: senderId,
      payload: {
        'reason': reason,
      },
    );
  }

  factory SyncMessage.hello({
    required String senderId,
    required String deviceName,
    int counter = 1,
  }) {
    return SyncMessage(
      id: _uuid.v4(),
      type: SyncMessageType.hello,
      counter: counter,
      senderId: senderId,
      payload: {
        'name': deviceName,
        'protocol_version': currentProtocolVersion,
      },
    );
  }

  factory SyncMessage.versionVector({
    required String senderId,
    required Map<String, int> vector,
    int counter = 1,
  }) {
    return SyncMessage(
      id: _uuid.v4(),
      type: SyncMessageType.versionVector,
      counter: counter,
      senderId: senderId,
      payload: {
        'vector': vector,
      },
    );
  }

  factory SyncMessage.changes({
    required String senderId,
    required List<Map<String, dynamic>> tasks,
    int batchIndex = 0,
    int totalBatches = 1,
    int counter = 1,
  }) {
    return SyncMessage(
      id: _uuid.v4(),
      type: SyncMessageType.changes,
      counter: counter,
      senderId: senderId,
      payload: {
        'tasks': tasks,
        'batch_index': batchIndex,
        'total_batches': totalBatches,
      },
    );
  }

  factory SyncMessage.ack({
    required String senderId,
    required int count,
    int counter = 1,
  }) {
    return SyncMessage(
      id: _uuid.v4(),
      type: SyncMessageType.ack,
      counter: counter,
      senderId: senderId,
      payload: {
        'status': 'ok',
        'count': count,
      },
    );
  }

  factory SyncMessage.error({
    required String senderId,
    required String code,
    required String message,
    int counter = 1,
  }) {
    return SyncMessage(
      id: _uuid.v4(),
      type: SyncMessageType.error,
      counter: counter,
      senderId: senderId,
      payload: {
        'code': code,
        'message': message,
      },
    );
  }

  factory SyncMessage.clipboardText({
    required String senderId,
    required String text,
    required String hash,
    int counter = 1,
  }) {
    return SyncMessage(
      id: _uuid.v4(),
      type: SyncMessageType.clipboardText,
      counter: counter,
      senderId: senderId,
      payload: {
        'text': text,
        'hash': hash,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  factory SyncMessage.fileMeta({
    required String senderId,
    required String transferId,
    required String fileName,
    required int fileSize,
    required String fileType,
    required String checksum,
    required int totalChunks,
    int counter = 1,
  }) {
    return SyncMessage(
      id: _uuid.v4(),
      type: SyncMessageType.fileMeta,
      counter: counter,
      senderId: senderId,
      payload: {
        'transfer_id': transferId,
        'file_name': fileName,
        'file_size': fileSize,
        'file_type': fileType,
        'checksum': checksum,
        'total_chunks': totalChunks,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  factory SyncMessage.fileChunk({
    required String senderId,
    required String transferId,
    required int chunkIndex,
    required int totalChunks,
    required String dataBase64,
    int counter = 1,
  }) {
    return SyncMessage(
      id: _uuid.v4(),
      type: SyncMessageType.fileChunk,
      counter: counter,
      senderId: senderId,
      payload: {
        'transfer_id': transferId,
        'chunk_index': chunkIndex,
        'total_chunks': totalChunks,
        'data': dataBase64,
      },
    );
  }

  factory SyncMessage.fileAck({
    required String senderId,
    required String transferId,
    required bool success,
    String? error,
    int counter = 1,
  }) {
    return SyncMessage(
      id: _uuid.v4(),
      type: SyncMessageType.fileAck,
      counter: counter,
      senderId: senderId,
      payload: {
        'transfer_id': transferId,
        'success': success,
        if (error != null) 'error': error,
      },
    );
  }
}
