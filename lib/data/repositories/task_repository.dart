import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';

/// All task reads/writes go through here. Every write bumps the revision,
/// stamps the device, and appends to change_log in ONE transaction, so the
/// future sync engine never misses a change.
class TaskRepository {
  TaskRepository(this._db, this.deviceId);

  final Database _db;
  final String deviceId;

  int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

  Future<List<Task>> list({
    bool includeCompleted = true,
    bool? onlyCompleted,
    String? category,
    String query = '',
  }) async {
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (onlyCompleted == true) {
      where.add('completed = 1');
    } else if (!includeCompleted || onlyCompleted == false) {
      where.add('completed = 0');
    }
    if (category != null && category.trim().isNotEmpty) {
      where.add('category = ?');
      args.add(category.trim());
    }
    final q = query.trim();
    if (q.isNotEmpty) {
      where.add('(title LIKE ? OR notes LIKE ? OR category LIKE ?)');
      args.addAll(['%$q%', '%$q%', '%$q%']);
    }
    final rows = await _db.query(
      'tasks',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy:
          'completed ASC, priority DESC, due_at IS NULL, due_at ASC, created_at DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<List<String>> categories() async {
    final rows = await _db.query(
      'tasks',
      distinct: true,
      columns: ['category'],
      where: "deleted = 0 AND category != ''",
      orderBy: 'category ASC',
    );
    return rows.map((r) => r['category'] as String).toList();
  }

  Future<Task> create({
    required String title,
    String notes = '',
    int? dueAt,
    int priority = 1,
    String category = '',
    Recurrence recurrence = Recurrence.none,
  }) async {
    final now = _now();
    final task = Task(
      id: const Uuid().v4(),
      title: title.trim(),
      notes: notes,
      dueAt: dueAt,
      priority: priority,
      category: category.trim(),
      recurrence: recurrence,
      createdAt: now,
      updatedAt: now,
    );
    return _db.transaction((txn) => _save(txn, task, 'create'));
  }

  Future<Task> update(Task task) =>
      _db.transaction((txn) => _save(txn, task, 'update'));

  /// Completing a recurring task with a due date advances the due date
  /// instead of marking it completed.
  Future<Task> toggleComplete(Task task) {
    if (!task.completed &&
        task.recurrence != Recurrence.none &&
        task.dueAt != null) {
      final step = task.recurrence == Recurrence.daily ? 1 : 7;
      final next = DateTime.fromMillisecondsSinceEpoch(task.dueAt!, isUtc: true)
          .add(Duration(days: step))
          .millisecondsSinceEpoch;
      return update(task.copyWith(dueAt: next));
    }
    return update(task.copyWith(completed: !task.completed));
  }

  /// Soft delete: keeps a tombstone so deletions propagate during sync.
  Future<void> delete(String id) async {
    await _db.transaction((txn) async {
      final rows = await txn.query('tasks', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      await _save(txn, Task.fromMap(rows.first).copyWith(deleted: true), 'delete');
    });
  }

  /// Changes not yet acknowledged by peers (used by the future sync engine).
  Future<List<Map<String, Object?>>> pendingChanges() =>
      _db.query('change_log', where: 'synced = 0', orderBy: 'seq ASC');

  Future<Task> _save(Transaction txn, Task task, String op) async {
    final saved = task.copyWith(
      updatedAt: _now(),
      revision: task.revision + 1,
      deviceId: deviceId,
    );
    await txn.insert('tasks', saved.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await txn.insert('change_log', {
      'task_id': saved.id,
      'op': op,
      'revision': saved.revision,
      'device_id': deviceId,
      'at': saved.updatedAt,
    });
    return saved;
  }
}
