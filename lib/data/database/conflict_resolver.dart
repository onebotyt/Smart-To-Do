import '../models/conflict_log_entry.dart';
import '../models/task.dart';

class ConflictResolution {
  const ConflictResolution({
    required this.task,
    required this.conflicts,
  });

  final Task task;
  final List<ConflictLogEntry> conflicts;
}

/// Resolves conflicting edits between local and incoming remote tasks.
/// Conforms to docs/SYNC_PROTOCOL.md:
/// - Merge per field.
/// - Last-write-wins by updated_at, tie-break by device_id.
/// - Delete vs edit: delete wins unless edit is strictly newer (resurrect).
class ConflictResolver {
  static ConflictResolution resolve({
    required Task local,
    required Task remote,
    Task? base,
    required String Function() idGenerator,
    required int now,
  }) {
    // 1. Delete vs Edit handling
    if (local.deleted != remote.deleted) {
      final tombstone = local.deleted ? local : remote;
      final edit = local.deleted ? remote : local;

      // Delete wins unless edit is newer than the tombstone (resurrect)
      if (edit.updatedAt > tombstone.updatedAt) {
        final resolvedRevision =
            (local.revision > remote.revision ? local.revision : remote.revision) + 1;
        return ConflictResolution(
          task: edit.copyWith(
            deleted: false,
            revision: resolvedRevision,
            updatedAt: now,
          ),
          conflicts: [
            ConflictLogEntry(
              id: idGenerator(),
              taskId: local.id,
              field: 'deleted',
              localValue: local.deleted.toString(),
              remoteValue: remote.deleted.toString(),
              resolvedValue: 'false',
              createdAt: now,
            ),
          ],
        );
      } else {
        final resolvedRevision =
            (local.revision > remote.revision ? local.revision : remote.revision) + 1;
        return ConflictResolution(
          task: tombstone.copyWith(
            deleted: true,
            revision: resolvedRevision,
            updatedAt: now,
          ),
          conflicts: [
            ConflictLogEntry(
              id: idGenerator(),
              taskId: local.id,
              field: 'deleted',
              localValue: local.deleted.toString(),
              remoteValue: remote.deleted.toString(),
              resolvedValue: 'true',
              createdAt: now,
            ),
          ],
        );
      }
    }

    // 2. Both deleted or both active: field-level merge
    final conflicts = <ConflictLogEntry>[];

    // Determine default winner: Last-Write-Wins by updatedAt, tie-break by deviceId
    final bool remoteWinsLww;
    if (remote.updatedAt > local.updatedAt) {
      remoteWinsLww = true;
    } else if (remote.updatedAt < local.updatedAt) {
      remoteWinsLww = false;
    } else {
      remoteWinsLww = remote.deviceId.compareTo(local.deviceId) > 0;
    }

    T resolveField<T>({
      required String fieldName,
      required T localValue,
      required T remoteValue,
      T? baseValue,
    }) {
      if (localValue == remoteValue) return localValue;

      // 3-way merge when base is present
      if (base != null) {
        final localModified = localValue != baseValue;
        final remoteModified = remoteValue != baseValue;

        if (localModified && !remoteModified) {
          return localValue;
        }
        if (remoteModified && !localModified) {
          return remoteValue;
        }
      }

      // Both modified or 2-way fallback: Last-Write-Wins
      final chosen = remoteWinsLww ? remoteValue : localValue;
      conflicts.add(ConflictLogEntry(
        id: idGenerator(),
        taskId: local.id,
        field: fieldName,
        localValue: localValue?.toString(),
        remoteValue: remoteValue?.toString(),
        resolvedValue: chosen?.toString(),
        createdAt: now,
      ));
      return chosen;
    }

    final resolvedTitle = resolveField<String>(
      fieldName: 'title',
      localValue: local.title,
      remoteValue: remote.title,
      baseValue: base?.title,
    );
    final resolvedNotes = resolveField<String>(
      fieldName: 'notes',
      localValue: local.notes,
      remoteValue: remote.notes,
      baseValue: base?.notes,
    );
    final resolvedDueAt = resolveField<int?>(
      fieldName: 'dueAt',
      localValue: local.dueAt,
      remoteValue: remote.dueAt,
      baseValue: base?.dueAt,
    );
    final resolvedPriority = resolveField<int>(
      fieldName: 'priority',
      localValue: local.priority,
      remoteValue: remote.priority,
      baseValue: base?.priority,
    );
    final resolvedCategory = resolveField<String>(
      fieldName: 'category',
      localValue: local.category,
      remoteValue: remote.category,
      baseValue: base?.category,
    );
    final resolvedCompleted = resolveField<bool>(
      fieldName: 'completed',
      localValue: local.completed,
      remoteValue: remote.completed,
      baseValue: base?.completed,
    );
    final resolvedRecurrence = resolveField<Recurrence>(
      fieldName: 'recurrence',
      localValue: local.recurrence,
      remoteValue: remote.recurrence,
      baseValue: base?.recurrence,
    );

    final resolvedRevision =
        (local.revision > remote.revision ? local.revision : remote.revision) +
            (conflicts.isNotEmpty ? 1 : 0);

    final resolvedDevice = remoteWinsLww ? remote.deviceId : local.deviceId;

    final resolvedTask = Task(
      id: local.id,
      title: resolvedTitle,
      notes: resolvedNotes,
      dueAt: resolvedDueAt,
      priority: resolvedPriority,
      category: resolvedCategory,
      completed: resolvedCompleted,
      recurrence: resolvedRecurrence,
      createdAt:
          local.createdAt < remote.createdAt ? local.createdAt : remote.createdAt,
      updatedAt: conflicts.isNotEmpty
          ? now
          : (remoteWinsLww ? remote.updatedAt : local.updatedAt),
      revision: resolvedRevision,
      deviceId: resolvedDevice,
      deleted: local.deleted,
    );

    return ConflictResolution(
      task: resolvedTask,
      conflicts: conflicts,
    );
  }
}
