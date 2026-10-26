import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synctask/data/database/app_database.dart';
import 'package:synctask/data/models/device.dart';
import 'package:synctask/data/repositories/device_repository.dart';

void main() {
  late Database db;
  late DeviceRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repo = DeviceRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('saves and retrieves devices correctly', () async {
    final now = DateTime.now();
    final device = Device(
      id: 'phone-001',
      name: 'Pixel 8',
      fingerprint: 'sha256:abcd1234',
      ipAddress: '192.168.1.50',
      port: 43884,
      pairedAt: now,
      lastSeen: now,
      trusted: true,
    );

    await repo.save(device);

    final retrieved = await repo.getById('phone-001');
    expect(retrieved, isNotNull);
    expect(retrieved!.id, 'phone-001');
    expect(retrieved.name, 'Pixel 8');
    expect(retrieved.fingerprint, 'sha256:abcd1234');
    expect(retrieved.ipAddress, '192.168.1.50');
    expect(retrieved.port, 43884);
    expect(retrieved.trusted, isTrue);

    final all = await repo.getAll();
    expect(all.length, 1);
  });

  test('filters trusted vs revoked devices', () async {
    final now = DateTime.now();
    final dev1 = Device(
      id: 'dev-1',
      name: 'Trusted Tablet',
      fingerprint: 'fp-1',
      pairedAt: now,
      trusted: true,
    );
    final dev2 = Device(
      id: 'dev-2',
      name: 'Revoked Laptop',
      fingerprint: 'fp-2',
      pairedAt: now,
      trusted: false,
    );

    await repo.save(dev1);
    await repo.save(dev2);

    final trustedList = await repo.getTrustedDevices();
    expect(trustedList.length, 1);
    expect(trustedList.first.id, 'dev-1');

    // Revoke dev-1
    await repo.setTrust('dev-1', false);
    final afterRevoke = await repo.getTrustedDevices();
    expect(afterRevoke.isEmpty, isTrue);

    // Re-trust dev-2
    await repo.setTrust('dev-2', true);
    final afterTrust = await repo.getTrustedDevices();
    expect(afterTrust.length, 1);
    expect(afterTrust.first.id, 'dev-2');
  });

  test('updates last_seen and network address', () async {
    final now = DateTime.now();
    final dev = Device(
      id: 'dev-update',
      name: 'Test Device',
      fingerprint: 'fp-update',
      pairedAt: now,
    );
    await repo.save(dev);

    final later = now.add(const Duration(minutes: 5));
    await repo.updateLastSeen(
      'dev-update',
      ipAddress: '10.0.0.99',
      port: 43885,
      timestamp: later,
    );

    final updated = await repo.getById('dev-update');
    expect(updated!.ipAddress, '10.0.0.99');
    expect(updated.port, 43885);
    expect(updated.lastSeen?.millisecondsSinceEpoch, later.millisecondsSinceEpoch);
  });

  test('deletes device', () async {
    final dev = Device(
      id: 'dev-del',
      name: 'Delete Me',
      fingerprint: 'fp',
      pairedAt: DateTime.now(),
    );
    await repo.save(dev);
    expect((await repo.getAll()).length, 1);

    await repo.delete('dev-del');
    expect((await repo.getAll()).isEmpty, isTrue);
    expect(await repo.getById('dev-del'), isNull);
  });

  test('local device id and device name management', () async {
    final localId = await repo.getLocalDeviceId();
    expect(localId.isNotEmpty, isTrue);

    final initialName = await repo.getLocalDeviceName();
    expect(initialName.isNotEmpty, isTrue);

    await repo.setLocalDeviceName('Custom Work PC');
    final updatedName = await repo.getLocalDeviceName();
    expect(updatedName, 'Custom Work PC');
  });
}
