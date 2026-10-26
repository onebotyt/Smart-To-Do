import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:synctask/data/database/app_database.dart';
import 'package:synctask/data/models/device.dart';

class DeviceRepository {
  final Database _db;

  DeviceRepository(this._db);

  /// Fetch all registered devices.
  Future<List<Device>> getAll() async {
    final rows = await _db.query('devices', orderBy: 'paired_at DESC');
    return rows.map(Device.fromMap).toList();
  }

  /// Fetch only trusted devices eligible for sync.
  Future<List<Device>> getTrustedDevices() async {
    final rows = await _db.query(
      'devices',
      where: 'trusted = 1',
      orderBy: 'paired_at DESC',
    );
    return rows.map(Device.fromMap).toList();
  }

  /// Get a single device by ID.
  Future<Device?> getById(String id) async {
    final rows = await _db.query(
      'devices',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Device.fromMap(rows.first);
  }

  /// Insert or update a device (prevents duplicates with same IP).
  Future<void> save(Device device) async {
    if (device.ipAddress != null && device.ipAddress!.isNotEmpty) {
      await _db.delete(
        'devices',
        where: 'ip_address = ? AND id != ?',
        whereArgs: [device.ipAddress, device.id],
      );
    }
    await _db.insert(
      'devices',
      device.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update the last seen timestamp and optionally update its network address.
  Future<void> updateLastSeen(
    String id, {
    String? ipAddress,
    int? port,
    DateTime? timestamp,
  }) async {
    final values = <String, dynamic>{
      'last_seen': (timestamp ?? DateTime.now()).millisecondsSinceEpoch,
    };
    if (ipAddress != null) {
      values['ip_address'] = ipAddress;
    }
    if (port != null) {
      values['port'] = port;
    }
    await _db.update(
      'devices',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update trust status (true = active, false = revoked).
  Future<void> setTrust(String id, bool trusted) async {
    await _db.update(
      'devices',
      {'trusted': trusted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Completely remove a paired device.
  Future<void> delete(String id) async {
    await _db.delete('devices', where: 'id = ?', whereArgs: [id]);
  }

  /// Get the local device ID.
  Future<String> getLocalDeviceId() async {
    return AppDatabase.deviceId(_db);
  }

  /// Get the friendly local device name (e.g. "Windows Desktop", "Android Phone").
  Future<String> getLocalDeviceName() async {
    final rows = await _db.query('meta', where: "key = 'device_name'");
    if (rows.isNotEmpty) {
      final name = rows.first['value'] as String?;
      if (name != null && name.trim().isNotEmpty) {
        return name;
      }
    }

    // Default friendly name based on platform
    String defaultName;
    try {
      if (Platform.isAndroid) {
        defaultName = 'Android Device';
      } else if (Platform.isWindows) {
        defaultName = 'Windows PC';
      } else if (Platform.isIOS) {
        defaultName = 'iOS Device';
      } else if (Platform.isMacOS) {
        defaultName = 'Mac';
      } else if (Platform.isLinux) {
        defaultName = 'Linux PC';
      } else {
        defaultName = 'SyncTask Device';
      }
    } catch (_) {
      defaultName = 'SyncTask Device';
    }

    await setLocalDeviceName(defaultName);
    return defaultName;
  }

  /// Update the friendly local device name.
  Future<void> setLocalDeviceName(String name) async {
    await _db.insert(
      'meta',
      {'key': 'device_name', 'value': name.trim()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
