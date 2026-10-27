/// Represents an item of persistent memory shared between SyncTask and Studio.
class MemoryItem {
  final String id;
  final String content;
  final String category;
  final String source;
  final double confidence;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  MemoryItem({
    required this.id,
    required this.content,
    this.category = 'general',
    this.source = 'user',
    this.confidence = 1.0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.metadata = const {},
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'content': content.trim(),
        'category': category,
        'source': source,
        'confidence': confidence,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'meta_json': metadata.isEmpty ? '{}' : metadata.toString(),
      };

  factory MemoryItem.fromMap(Map<String, dynamic> map) {
    return MemoryItem(
      id: map['id'] as String,
      content: map['content'] as String,
      category: (map['category'] as String?) ?? 'general',
      source: (map['source'] as String?) ?? 'user',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
    );
  }
}

/// Represents a single message in a conversation with Sky AI.
class ConversationMessage {
  final String id;
  final String sessionId;
  final String role;
  final String content;
  final DateTime createdAt;

  ConversationMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'role': role,
        'content': content.trim(),
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ConversationMessage.fromMap(Map<String, dynamic> map) {
    return ConversationMessage(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
    );
  }
}
