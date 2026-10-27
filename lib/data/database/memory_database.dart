import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Isolated SQLite database for shared AI memories, knowledge, and conversation context.
/// Completely independent of `synctask.db` to prevent any task data corruption.
class MemoryDatabase {
  static const int version = 1;

  static Future<Database> open({String? path}) async {
    final dbPath = path ??
        p.join((await getApplicationSupportDirectory()).path, 'memory.db');

    return openDatabase(
      dbPath,
      version: version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
      },
      onCreate: (db, v) async {
        // Semantic and factual memory table
        await db.execute('''
          CREATE TABLE memories (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'general',
            source TEXT NOT NULL DEFAULT 'user',
            confidence REAL NOT NULL DEFAULT 1.0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            meta_json TEXT NOT NULL DEFAULT '{}'
          )
        ''');
        await db.execute('CREATE INDEX idx_memories_cat ON memories(category)');
        await db.execute('CREATE INDEX idx_memories_updated ON memories(updated_at DESC)');

        // Conversation history table
        await db.execute('''
          CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_conv_session ON conversations(session_id, created_at ASC)');
      },
    );
  }

  /// Adds a new memory record.
  static Future<String> addMemory(
    Database db, {
    required String content,
    String category = 'general',
    String source = 'user',
    double confidence = 1.0,
    Map<String, dynamic> metadata = const {},
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'memories',
      {
        'id': id,
        'content': content.trim(),
        'category': category,
        'source': source,
        'confidence': confidence,
        'created_at': now,
        'updated_at': now,
        'meta_json': metadata.isEmpty ? '{}' : metadata.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  /// Retrieves recent memories by category.
  static Future<List<Map<String, dynamic>>> getMemories(
    Database db, {
    String? category,
    int limit = 50,
  }) async {
    if (category != null && category.isNotEmpty) {
      return db.query(
        'memories',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'updated_at DESC',
        limit: limit,
      );
    }
    return db.query(
      'memories',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
  }

  /// Searches memories matching keyword terms.
  static Future<List<Map<String, dynamic>>> searchMemories(
    Database db,
    String query, {
    int limit = 20,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    return db.query(
      'memories',
      where: 'content LIKE ? OR category LIKE ?',
      whereArgs: ['%$q%', '%$q%'],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
  }

  /// Appends a message to conversation history.
  static Future<void> addMessage(
    Database db, {
    required String sessionId,
    required String role,
    required String content,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('conversations', {
      'id': id,
      'session_id': sessionId,
      'role': role,
      'content': content,
      'created_at': now,
    });
  }

  /// Fetches conversation messages for a session in chronological order.
  static Future<List<Map<String, dynamic>>> getSessionMessages(
    Database db,
    String sessionId, {
    int limit = 100,
  }) async {
    return db.query(
      'conversations',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }
}
