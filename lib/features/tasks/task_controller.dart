import 'package:flutter/foundation.dart';

import '../../data/models/task.dart';
import '../../data/repositories/task_repository.dart';
import '../settings/settings_controller.dart';

enum TaskFilter { all, pending, completed }

class TaskController extends ChangeNotifier {
  TaskController(this._repo, this._settings) {
    _settings.addListener(refresh);
  }

  final TaskRepository _repo;
  final SettingsController _settings;

  List<Task> tasks = [];
  List<String> categories = [];
  String? selectedCategory;
  TaskFilter filter = TaskFilter.all;
  String query = '';

  Future<void> refresh() async {
    categories = await _repo.categories();
    if (selectedCategory != null && !categories.contains(selectedCategory)) {
      selectedCategory = null;
    }

    bool includeCompleted = _settings.showCompleted;
    bool? onlyCompleted;
    if (filter == TaskFilter.pending) {
      includeCompleted = false;
      onlyCompleted = false;
    } else if (filter == TaskFilter.completed) {
      includeCompleted = true;
      onlyCompleted = true;
    }

    tasks = await _repo.list(
      includeCompleted: includeCompleted,
      onlyCompleted: onlyCompleted,
      category: selectedCategory,
      query: query,
    );
    notifyListeners();
  }

  Future<void> setQuery(String q) async {
    query = q;
    await refresh();
  }

  Future<void> setSelectedCategory(String? category) async {
    selectedCategory = category;
    await refresh();
  }

  Future<void> setFilter(TaskFilter f) async {
    filter = f;
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
