enum Recurrence { none, daily, weekly }

/// A task. Sync-ready: UUID, revision, last-modifying device, tombstone.
class Task {
  const Task({
    required this.id,
    required this.title,
    this.notes = '',
    this.dueAt,
    this.priority = 1,
    this.category = '',
    this.completed = false,
    this.recurrence = Recurrence.none,
    required this.createdAt,
    required this.updatedAt,
    this.revision = 0,
    this.deviceId = '',
    this.deleted = false,
  });

  final String id;
  final String title;
  final String notes;
  final int? dueAt; // epoch millis (UTC)
  final int priority; // 0 low, 1 normal, 2 high
  final String category;
  final bool completed;
  final Recurrence recurrence;
  final int createdAt;
  final int updatedAt;
  final int revision;
  final String deviceId;
  final bool deleted; // tombstone

  Task copyWith({
    String? title,
    String? notes,
    int? dueAt,
    bool clearDueAt = false,
    int? priority,
    String? category,
    bool? completed,
    Recurrence? recurrence,
    int? updatedAt,
    int? revision,
    String? deviceId,
    bool? deleted,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
        priority: priority ?? this.priority,
        category: category ?? this.category,
        completed: completed ?? this.completed,
        recurrence: recurrence ?? this.recurrence,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        revision: revision ?? this.revision,
        deviceId: deviceId ?? this.deviceId,
        deleted: deleted ?? this.deleted,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'notes': notes,
        'due_at': dueAt,
        'priority': priority,
        'category': category,
        'completed': completed ? 1 : 0,
        'recurrence': recurrence.name,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'revision': revision,
        'device_id': deviceId,
        'deleted': deleted ? 1 : 0,
      };

  factory Task.fromMap(Map<String, Object?> m) => Task(
        id: m['id'] as String,
        title: m['title'] as String,
        notes: (m['notes'] as String?) ?? '',
        dueAt: m['due_at'] as int?,
        priority: m['priority'] as int,
        category: (m['category'] as String?) ?? '',
        completed: (m['completed'] as int) == 1,
        recurrence: Recurrence.values.byName(m['recurrence'] as String),
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
        revision: m['revision'] as int,
        deviceId: m['device_id'] as String,
        deleted: (m['deleted'] as int) == 1,
      );
}
