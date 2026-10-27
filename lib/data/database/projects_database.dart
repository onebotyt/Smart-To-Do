import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Isolated SQLite database for AI Engineering Studio projects, sessions, and recovery checkpoints.
/// Only loaded and accessed when AI Engineering Studio is actively running.
class ProjectsDatabase {
  static const int version = 1;

  static Future<Database> open({String? path}) async {
    final dbPath = path ??
        p.join((await getApplicationSupportDirectory()).path, 'projects.db');

    return openDatabase(
      dbPath,
      version: version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
      },
      onCreate: (db, v) async {
        // Projects table
        await db.execute('''
          CREATE TABLE projects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            root_path TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_projects_updated ON projects(updated_at DESC)');

        // Agent / Engineering sessions table
        await db.execute('''
          CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            title TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'active',
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_sessions_project ON sessions(project_id)');

        // Checkpoints / recovery table
        await db.execute('''
          CREATE TABLE checkpoints (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            step_index INTEGER NOT NULL,
            summary TEXT NOT NULL,
            git_commit TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_checkpoints_session ON checkpoints(session_id, step_index ASC)');
      },
    );
  }

  /// Creates a new project in the studio database.
  static Future<String> createProject(
    Database db, {
    required String name,
    required String rootPath,
    String description = '',
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('projects', {
      'id': id,
      'name': name.trim(),
      'root_path': rootPath.trim(),
      'description': description.trim(),
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  /// Lists all projects.
  static Future<List<Map<String, dynamic>>> listProjects(Database db) async {
    return db.query('projects', orderBy: 'updated_at DESC');
  }

  /// Retrieves a project by ID.
  static Future<Map<String, dynamic>?> getProject(Database db, String id) async {
    final rows = await db.query('projects', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Starts a new engineering session.
  static Future<String> startSession(
    Database db, {
    required String projectId,
    required String title,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('sessions', {
      'id': id,
      'project_id': projectId,
      'title': title.trim(),
      'status': 'active',
      'started_at': now,
    });
    return id;
  }

  /// Records a checkpoint step.
  static Future<void> saveCheckpoint(
    Database db, {
    required String sessionId,
    required int stepIndex,
    required String summary,
    String? gitCommit,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('checkpoints', {
      'id': id,
      'session_id': sessionId,
      'step_index': stepIndex,
      'summary': summary.trim(),
      'git_commit': gitCommit,
      'created_at': now,
    });
  }

  /// Marks a session as finished.
  static Future<void> finishSession(
    Database db,
    String sessionId, {
    String status = 'completed',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'sessions',
      {
        'status': status,
        'ended_at': now,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }
}
