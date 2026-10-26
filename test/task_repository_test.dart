import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synctask/data/database/app_database.dart';
import 'package:synctask/data/models/task.dart';
import 'package:synctask/data/repositories/task_repository.dart';

void main() {
  late TaskRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    repo = TaskRepository(db, await AppDatabase.deviceId(db));
  });

  test('create bumps revision and writes change log', () async {
    final t = await repo.create(title: 'Buy milk');
    expect(t.revision, 1);
    final log = await repo.pendingChanges();
    expect(log.single['op'], 'create');
  });

  test('delete keeps a tombstone but hides the task', () async {
    final t = await repo.create(title: 'Temp');
    await repo.delete(t.id);
    expect(await repo.list(), isEmpty);
    final ops = (await repo.pendingChanges()).map((e) => e['op']).toList();
    expect(ops, ['create', 'delete']);
  });

  test('search and completed filter', () async {
    final a = await repo.create(title: 'Alpha');
    await repo.create(title: 'Beta');
    await repo.toggleComplete(a);
    expect((await repo.list(query: 'alp')).length, 1);
    expect((await repo.list(includeCompleted: false)).length, 1);
  });

  test('recurring task advances due date instead of completing', () async {
    final due = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    final t = await repo.create(
        title: 'Daily', dueAt: due, recurrence: Recurrence.daily);
    final next = await repo.toggleComplete(t);
    expect(next.completed, false);
    expect(next.dueAt, DateTime.utc(2026, 1, 2).millisecondsSinceEpoch);
  });
}
