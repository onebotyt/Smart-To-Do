import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synctask/data/database/app_database.dart';
import 'package:synctask/data/models/task.dart';
import 'package:synctask/data/repositories/task_repository.dart';

void main() {
  late Database db;
  late TaskRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    final deviceId = await AppDatabase.deviceId(db);
    repo = TaskRepository(db, deviceId);
  });

  tearDown(() async {
    await db.close();
  });

  group('Tombstones and Change Queue', () {
    test('purgeTombstones only purges expired and synced deletions', () async {
      // 1. Create task and delete it
      final task = await repo.create(title: 'Tombstone Task');
      await repo.delete(task.id);

      // Verify soft deleted
      expect(await repo.list(), isEmpty);
      final rawDeleted = await db.query('tasks', where: 'id = ?', whereArgs: [task.id]);
      expect(rawDeleted.first['deleted'], 1);

      // 2. Attempt purge with 30 days retention: recent deletion should NOT be purged
      var purged = await repo.purgeTombstones(retention: const Duration(days: 30));
      expect(purged, 0);

      // 3. Artificially backdate the tombstone updated_at to 40 days ago
      final fortyDaysAgo =
          DateTime.now().toUtc().subtract(const Duration(days: 40)).millisecondsSinceEpoch;
      await db.update('tasks', {'updated_at': fortyDaysAgo}, where: 'id = ?', whereArgs: [task.id]);

      // But change_log row is still synced = 0 -> MUST NOT PURGE yet
      purged = await repo.purgeTombstones(retention: const Duration(days: 30));
      expect(purged, 0);

      // 4. Mark all changes as synced
      final unsynced = await repo.getUnsyncedChanges();
      final maxSeq = unsynced.last['seq'] as int;
      await repo.markChangesSynced(maxSeq);

      // Now it is older than retention AND synced -> PURGE SUCCEEDS
      purged = await repo.purgeTombstones(retention: const Duration(days: 30));
      expect(purged, 1);

      final checkDeleted = await db.query('tasks', where: 'id = ?', whereArgs: [task.id]);
      expect(checkDeleted, isEmpty);
    });

    test('getUnsyncedChanges returns monotonic sequences and updates with markChangesSynced', () async {
      await repo.create(title: 'Task A');
      await repo.create(title: 'Task B');
      await repo.create(title: 'Task C');

      final changes = await repo.getUnsyncedChanges();
      expect(changes.length, 3);

      final seqs = changes.map((c) => c['seq'] as int).toList();
      expect(seqs[0] < seqs[1], isTrue);
      expect(seqs[1] < seqs[2], isTrue);

      // Mark the first 2 changes synced
      await repo.markChangesSynced(seqs[1]);

      final remaining = await repo.getUnsyncedChanges();
      expect(remaining.length, 1);
      expect(remaining.first['seq'], seqs[2]);
    });

    test('applyRemoteTask resolves conflicts and records entries in conflict_log', () async {
      // Create local task
      final local = await repo.create(title: 'Local Shopping');

      // Prepare conflicting remote task with newer timestamp
      final remote = Task(
        id: local.id,
        title: 'Remote Groceries',
        notes: 'Remote notes',
        category: 'Food',
        createdAt: local.createdAt,
        updatedAt: local.updatedAt + 5000,
        revision: local.revision,
        deviceId: 'device-peer',
      );

      final applied = await repo.applyRemoteTask(remote);
      expect(applied.title, 'Remote Groceries');

      // Verify conflict log recorded the overridden local title
      final conflicts = await repo.getConflicts(taskId: local.id);
      expect(conflicts.isNotEmpty, isTrue);
      expect(conflicts.any((c) => c.field == 'title'), isTrue);
    });
  });
}
