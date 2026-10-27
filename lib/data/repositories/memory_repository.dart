import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/memory_database.dart';
import '../models/memory_item.dart';

/// Repository managing shared persistent memories, rules, and conversation logs.
/// Uses bounded queries to protect memory footprint on 8 GB host machines.
class MemoryRepository {
  final Database _db;

  MemoryRepository(this._db);

  static Future<MemoryRepository> open({String? path}) async {
    final db = await MemoryDatabase.open(path: path);
    return MemoryRepository(db);
  }

  /// Saves or updates a memory item.
  Future<String> saveMemory({
    String? id,
    required String content,
    String category = 'general',
    String source = 'user',
    double confidence = 1.0,
    Map<String, dynamic> metadata = const {},
  }) async {
    final memoryId = id ?? const Uuid().v4();
    final item = MemoryItem(
      id: memoryId,
      content: content,
      category: category,
      source: source,
      confidence: confidence,
      metadata: metadata,
    );

    await _db.insert(
      'memories',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return memoryId;
  }

  /// Retrieves memories with bounded query limits.
  Future<List<MemoryItem>> getMemories({
    String? category,
    int limit = 25,
  }) async {
    final clampedLimit = limit.clamp(1, 100);
    List<Map<String, dynamic>> rows;

    if (category != null && category.isNotEmpty) {
      rows = await _db.query(
        'memories',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'updated_at DESC',
        limit: clampedLimit,
      );
    } else {
      rows = await _db.query(
        'memories',
        orderBy: 'updated_at DESC',
        limit: clampedLimit,
      );
    }

    return rows.map(MemoryItem.fromMap).toList();
  }

  /// Searches memories matching keyword terms.
  Future<List<MemoryItem>> searchMemories(
    String query, {
    int limit = 15,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final clampedLimit = limit.clamp(1, 50);
    final rows = await _db.query(
      'memories',
      where: 'content LIKE ? OR category LIKE ?',
      whereArgs: ['%$q%', '%$q%'],
      orderBy: 'updated_at DESC',
      limit: clampedLimit,
    );

    return rows.map(MemoryItem.fromMap).toList();
  }

  /// Deletes a memory item by ID.
  Future<void> deleteMemory(String id) async {
    await _db.delete('memories', where: 'id = ?', whereArgs: [id]);
  }

  /// Appends a message to conversation history.
  Future<void> recordMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    final id = const Uuid().v4();
    final msg = ConversationMessage(
      id: id,
      sessionId: sessionId,
      role: role,
      content: content,
    );

    await _db.insert(
      'conversations',
      msg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves chronological conversation history for a session.
  Future<List<ConversationMessage>> getConversationHistory(
    String sessionId, {
    int limit = 50,
  }) async {
    final clampedLimit = limit.clamp(1, 100);
    final rows = await _db.query(
      'conversations',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
      limit: clampedLimit,
    );

    return rows.map(ConversationMessage.fromMap).toList();
  }

  /// Clears conversation history for a session.
  Future<void> clearConversation(String sessionId) async {
    await _db.delete('conversations', where: 'session_id = ?', whereArgs: [sessionId]);
  }
}
