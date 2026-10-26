import 'package:flutter_test/flutter_test.dart';
import 'package:synctask/features/sync/models/sync_message.dart';

void main() {
  group('SyncMessage serialization and parsing', () {
    test('pairRequest round-trip', () {
      final msg = SyncMessage.pairRequest(
        senderId: 'dev-alice',
        deviceName: 'Alice Phone',
        pairingCode: '123456',
        fingerprint: 'sha256:alice123',
        counter: 1,
      );

      final jsonStr = msg.toJson();
      final parsed = SyncMessage.fromJson(jsonStr);

      expect(parsed.id, msg.id);
      expect(parsed.type, SyncMessageType.pairRequest);
      expect(parsed.senderId, 'dev-alice');
      expect(parsed.counter, 1);
      expect(parsed.payload['name'], 'Alice Phone');
      expect(parsed.payload['pairing_code'], '123456');
      expect(parsed.payload['fingerprint'], 'sha256:alice123');
    });

    test('pairAccept round-trip', () {
      final msg = SyncMessage.pairAccept(
        senderId: 'dev-bob',
        deviceName: 'Bob PC',
        fingerprint: 'sha256:bob456',
        counter: 2,
      );

      final parsed = SyncMessage.fromJson(msg.toJson());
      expect(parsed.type, SyncMessageType.pairAccept);
      expect(parsed.senderId, 'dev-bob');
      expect(parsed.counter, 2);
      expect(parsed.payload['name'], 'Bob PC');
      expect(parsed.payload['fingerprint'], 'sha256:bob456');
    });

    test('changes and ack round-trip', () {
      final taskMap = {
        'id': 'task-1',
        'title': 'Test Sync',
        'revision': 1,
        'device_id': 'dev-alice',
      };

      final changesMsg = SyncMessage.changes(
        senderId: 'dev-alice',
        tasks: [taskMap],
        batchIndex: 0,
        totalBatches: 1,
        counter: 3,
      );

      final parsedChanges = SyncMessage.fromJson(changesMsg.toJson());
      expect(parsedChanges.type, SyncMessageType.changes);
      final tasks = parsedChanges.payload['tasks'] as List;
      expect(tasks.length, 1);
      expect(tasks.first['title'], 'Test Sync');

      final ackMsg = SyncMessage.ack(
        senderId: 'dev-bob',
        count: 1,
        counter: 4,
      );
      final parsedAck = SyncMessage.fromJson(ackMsg.toJson());
      expect(parsedAck.type, SyncMessageType.ack);
      expect(parsedAck.payload['count'], 1);
      expect(parsedAck.payload['status'], 'ok');
    });

    test('throws FormatException on malformed message', () {
      expect(() => SyncMessage.fromJson('not json'), throwsFormatException);
      expect(
        () => SyncMessage.fromJson('{"id": "1", "protocol_version": 1}'),
        throwsFormatException,
      );
    });
  });
}
