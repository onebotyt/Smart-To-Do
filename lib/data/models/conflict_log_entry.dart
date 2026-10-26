class ConflictLogEntry {
  const ConflictLogEntry({
    required this.id,
    required this.taskId,
    required this.field,
    this.localValue,
    this.remoteValue,
    this.resolvedValue,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String field;
  final String? localValue;
  final String? remoteValue;
  final String? resolvedValue;
  final int createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'task_id': taskId,
        'field': field,
        'local_value': localValue,
        'remote_value': remoteValue,
        'resolved_value': resolvedValue,
        'created_at': createdAt,
      };

  factory ConflictLogEntry.fromMap(Map<String, Object?> m) => ConflictLogEntry(
        id: m['id'] as String,
        taskId: m['task_id'] as String,
        field: m['field'] as String,
        localValue: m['local_value'] as String?,
        remoteValue: m['remote_value'] as String?,
        resolvedValue: m['resolved_value'] as String?,
        createdAt: m['created_at'] as int,
      );
}
