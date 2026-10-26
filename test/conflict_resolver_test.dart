import 'package:flutter_test/flutter_test.dart';
import 'package:synctask/data/database/conflict_resolver.dart';
import 'package:synctask/data/models/task.dart';

void main() {
  var idCounter = 0;
  String testIdGenerator() => 'conflict-id-${++idCounter}';

  group('ConflictResolver', () {
    test('merges non-overlapping fields without losing either change', () {
      const local = Task(
        id: 'task-1',
        title: 'Original Title',
        notes: 'Local updated notes',
        category: 'General',
        priority: 1,
        completed: false,
        recurrence: Recurrence.none,
        createdAt: 1000,
        updatedAt: 2000,
        revision: 2,
        deviceId: 'device-local',
        deleted: false,
      );

      const remote = Task(
        id: 'task-1',
        title: 'Original Title',
        notes: 'Old notes',
        category: 'Personal', // Remote updated category
        priority: 1,
        completed: false,
        recurrence: Recurrence.none,
        createdAt: 1000,
        updatedAt: 2500,
        revision: 2,
        deviceId: 'device-remote',
        deleted: false,
      );

      const base = Task(
        id: 'task-1',
        title: 'Original Title',
        notes: 'Old notes',
        category: 'General',
        priority: 1,
        completed: false,
        recurrence: Recurrence.none,
        createdAt: 1000,
        updatedAt: 1000,
        revision: 1,
        deviceId: 'device-origin',
        deleted: false,
      );

      final resolution = ConflictResolver.resolve(
        local: local,
        remote: remote,
        base: base,
        idGenerator: testIdGenerator,
        now: 3000,
      );

      // Notes should be preserved from local and Category from remote
      expect(resolution.task.title, 'Original Title');
      expect(resolution.task.notes, 'Local updated notes');
      expect(resolution.task.category, 'Personal');
    });

    test('same field conflict uses Last-Write-Wins based on updatedAt', () {
      const local = Task(
        id: 'task-1',
        title: 'Local Title',
        notes: '',
        createdAt: 1000,
        updatedAt: 3000, // Newer edit
        revision: 2,
        deviceId: 'device-local',
      );

      const remote = Task(
        id: 'task-1',
        title: 'Remote Title',
        notes: '',
        createdAt: 1000,
        updatedAt: 2000, // Older edit
        revision: 2,
        deviceId: 'device-remote',
      );

      final resolution = ConflictResolver.resolve(
        local: local,
        remote: remote,
        idGenerator: testIdGenerator,
        now: 4000,
      );

      expect(resolution.task.title, 'Local Title');
      expect(resolution.conflicts.length, 1);
      expect(resolution.conflicts.first.field, 'title');
      expect(resolution.conflicts.first.localValue, 'Local Title');
      expect(resolution.conflicts.first.remoteValue, 'Remote Title');
      expect(resolution.conflicts.first.resolvedValue, 'Local Title');
    });

    test('deterministic tie-breaker uses deviceId when updatedAt is identical', () {
      const local = Task(
        id: 'task-1',
        title: 'Local Title',
        notes: '',
        createdAt: 1000,
        updatedAt: 2000,
        revision: 2,
        deviceId: 'device-A',
      );

      const remote = Task(
        id: 'task-1',
        title: 'Remote Title',
        notes: '',
        createdAt: 1000,
        updatedAt: 2000,
        revision: 2,
        deviceId: 'device-B', // B > A lexicographically
      );

      const base = Task(
        id: 'task-1',
        title: 'Original Title',
        notes: 'Old notes',
        category: 'General',
        priority: 1,
        completed: false,
        recurrence: Recurrence.none,
        createdAt: 1000,
        updatedAt: 1000,
        revision: 1,
        deviceId: 'device-origin',
        deleted: false,
      );

      final resolution = ConflictResolver.resolve(
        local: local,
        remote: remote,
        base: base,
        idGenerator: testIdGenerator,
        now: 3000,
      );

      expect(resolution.task.title, 'Remote Title');
      expect(resolution.task.deviceId, 'device-B');
    });

    test('delete vs edit: edit newer than tombstone resurrects the task', () {
      const localTombstone = Task(
        id: 'task-1',
        title: 'Deleted Task',
        notes: '',
        createdAt: 1000,
        updatedAt: 2000, // Deleted at 2000
        revision: 2,
        deviceId: 'device-local',
        deleted: true,
      );

      const remoteEdit = Task(
        id: 'task-1',
        title: 'Resurrected Task',
        notes: 'Edited after deletion',
        createdAt: 1000,
        updatedAt: 3000, // Edited at 3000 (after deletion)
        revision: 3,
        deviceId: 'device-remote',
        deleted: false,
      );

      final resolution = ConflictResolver.resolve(
        local: localTombstone,
        remote: remoteEdit,
        idGenerator: testIdGenerator,
        now: 4000,
      );

      expect(resolution.task.deleted, isFalse);
      expect(resolution.task.title, 'Resurrected Task');
      expect(resolution.conflicts.any((c) => c.field == 'deleted'), isTrue);
    });

    test('delete vs edit: tombstone newer than edit preserves deletion', () {
      const localTombstone = Task(
        id: 'task-1',
        title: 'Deleted Task',
        notes: '',
        createdAt: 1000,
        updatedAt: 4000, // Deleted at 4000
        revision: 3,
        deviceId: 'device-local',
        deleted: true,
      );

      const remoteEdit = Task(
        id: 'task-1',
        title: 'Old Edit',
        notes: '',
        createdAt: 1000,
        updatedAt: 2000, // Edited at 2000 (before deletion)
        revision: 2,
        deviceId: 'device-remote',
        deleted: false,
      );

      final resolution = ConflictResolver.resolve(
        local: localTombstone,
        remote: remoteEdit,
        idGenerator: testIdGenerator,
        now: 5000,
      );

      expect(resolution.task.deleted, isTrue);
    });
  });
}
