import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synctask/data/database/app_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v1 database upgrades cleanly to v2 without data loss', () async {
    final tempDir = Directory.systemTemp.createTempSync('synctask_migration_');
    final dbFile = p.join(tempDir.path, 'v1_upgrade_test.db');
    addTearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    // 1. Create a database strictly with Schema Version 1
    final v1Db = await openDatabase(
      dbFile,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            due_at INTEGER,
            priority INTEGER NOT NULL DEFAULT 1,
            category TEXT NOT NULL DEFAULT '',
            completed INTEGER NOT NULL DEFAULT 0,
            recurrence TEXT NOT NULL DEFAULT 'none',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            revision INTEGER NOT NULL DEFAULT 0,
            device_id TEXT NOT NULL,
            deleted INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('CREATE INDEX idx_tasks_due ON tasks(due_at)');
        await db.execute('''
          CREATE TABLE change_log (
            seq INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id TEXT NOT NULL,
            op TEXT NOT NULL,
            revision INTEGER NOT NULL,
            device_id TEXT NOT NULL,
            at INTEGER NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute(
            'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      },
    );

    // Insert v1 data
    await v1Db.insert('tasks', {
      'id': 'task-101',
      'title': 'Original Task in v1',
      'notes': 'Must survive migration',
      'due_at': 1700000000,
      'priority': 2,
      'category': 'Work',
      'completed': 0,
      'recurrence': 'none',
      'created_at': 1700000000,
      'updated_at': 1700000000,
      'revision': 1,
      'device_id': 'device-A',
      'deleted': 0,
    });

    await v1Db.insert('change_log', {
      'task_id': 'task-101',
      'op': 'create',
      'revision': 1,
      'device_id': 'device-A',
      'at': 1700000000,
      'synced': 0,
    });

    await v1Db.insert('meta', {'key': 'device_id', 'value': 'device-A'});
    await v1Db.close();

    // 2. Open via AppDatabase.open() (which runs v2 migration onUpgrade)
    final upgradedDb = await AppDatabase.open(path: dbFile);
    addTearDown(() async => await upgradedDb.close());

    expect(await upgradedDb.getVersion(), 2);

    // 3. Verify original data was preserved
    final tasks = await upgradedDb.query('tasks', where: 'id = ?', whereArgs: ['task-101']);
    expect(tasks.length, 1);
    expect(tasks.first['title'], 'Original Task in v1');
    expect(tasks.first['notes'], 'Must survive migration');

    final changeLogs = await upgradedDb.query('change_log', where: 'task_id = ?', whereArgs: ['task-101']);
    expect(changeLogs.length, 1);
    expect(changeLogs.first['op'], 'create');

    final meta = await upgradedDb.query('meta', where: "key = 'device_id'");
    expect(meta.first['value'], 'device-A');

    // 4. Verify conflict_log table was created by v2 migration
    await upgradedDb.insert('conflict_log', {
      'id': 'conflict-1',
      'task_id': 'task-101',
      'field': 'title',
      'local_value': 'v1',
      'remote_value': 'v2',
      'resolved_value': 'v2',
      'created_at': 1700001000,
    });

    final conflicts = await upgradedDb.query('conflict_log', where: 'id = ?', whereArgs: ['conflict-1']);
    expect(conflicts.length, 1);
    expect(conflicts.first['field'], 'title');
  });
}
