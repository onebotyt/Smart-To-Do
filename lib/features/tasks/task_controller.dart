import 'package:flutter/foundation.dart';

import '../../data/models/task.dart';
import '../../data/repositories/task_repository.dart';
import '../settings/settings_controller.dart';

class TaskController extends ChangeNotifier {
  TaskController(this._repo, this._settings) {
    _settings.addListener(refresh);
  }

  final TaskRepository _repo;
  final SettingsController _settings;

  List<Task> tasks = [];
  String query = '';

  Future<void> refresh() async {
    tasks = await _repo.list(
      includeCompleted: _settings.showCompleted,
      query: query,
    );
    notifyListeners();
  }

  Future<void> setQuery(String q) async {
    query = q;
    await refresh();
  }

  Future<void> add({
    required String title,
    String notes = '',
    int? dueAt,
    int? priority,
    String category = '',
    Recurrence recurrence = Recurrence.none,
  }) async {
    await _repo.create(
      title: title,
      notes: notes,
      dueAt: dueAt,
      priority: priority ?? _settings.defaultPriority,
      category: category,
      recurrence: recurrence,
    );
    await refresh();
  }

  Future<void> save(Task t) async {
    await _repo.update(t);
    await refresh();
  }

  Future<void> toggle(Task t) async {
    await _repo.toggleComplete(t);
    await refresh();
  }

  Future<void> remove(Task t) async {
    await _repo.delete(t.id);
    await refresh();
  }

  @override
  void dispose() {
    _settings.removeListener(refresh);
    super.dispose();
  }
}
