import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Opens the local SQLite database and owns the schema.
/// Schema changes MUST go through a new migration (bump [version]).
class AppDatabase {
  static const int version = 1;

  /// Pass [path] (e.g. inMemoryDatabasePath) in tests.
  static Future<Database> open({String? path}) async {
    final dbPath = path ??
        p.join((await getApplicationSupportDirectory()).path, 'synctask.db');
    return openDatabase(
      dbPath,
      version: version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
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
  }

  /// Stable per-install device ID, created on first run.
  static Future<String> deviceId(Database db) async {
    final rows = await db.query('meta', where: "key = 'device_id'");
    if (rows.isNotEmpty) return rows.first['value'] as String;
    final id = const Uuid().v4();
    await db.insert('meta', {'key': 'device_id', 'value': id});
    return id;
  }
}
