import 'package:flutter/foundation.dart';

import '../../data/models/task.dart';
import '../../data/repositories/task_repository.dart';
import '../../platform/floating_panel_service.dart';
import '../../platform/widget_service.dart';
import '../settings/settings_controller.dart';

enum TaskFilter { all, pending, completed }

class TaskController extends ChangeNotifier {
  TaskController(
    this._repo,
    this._settings, [
    WidgetService? widgetService,
    this.onTasksMutated,
  ])  : _widgetService = widgetService ?? PlatformWidgetService() {
    _settings.addListener(refresh);
  }

  final TaskRepository _repo;
  final SettingsController _settings;
  final WidgetService? _widgetService;
  final VoidCallback? onTasksMutated;
  void Function(Task task, bool completed)? onTaskCompletionChanged;

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

    // Update native home-screen widget
    final pendingTasks = tasks.where((t) => !t.completed).toList();
    _widgetService?.updateWidget(
      pendingCount: pendingTasks.length,
      topTaskTitles: pendingTasks.map((t) => t.title).toList(),
    );
    PlatformFloatingPanelService().notifyTasksChanged();

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
    onTasksMutated?.call();
  }

  /// Alias for add
  Future<void> create({
    required String title,
    String notes = '',
    int? dueAt,
    int? priority,
    String category = '',
    Recurrence recurrence = Recurrence.none,
  }) =>
      add(
        title: title,
        notes: notes,
        dueAt: dueAt,
        priority: priority,
        category: category,
        recurrence: recurrence,
      );

  Future<void> save(Task t) async {
    await _repo.update(t);
    await refresh();
    onTasksMutated?.call();
  }

  Future<void> toggle(Task t) async {
    final willBeCompleted = !t.completed;
    await _repo.toggleComplete(t);
    await refresh();
    onTasksMutated?.call();
    onTaskCompletionChanged?.call(t, willBeCompleted);
  }

  /// Alias for toggle
  Future<void> toggleComplete(Task t) => toggle(t);

  Future<void> remove(Task t) async {
    await _repo.delete(t.id);
    await refresh();
    onTasksMutated?.call();
  }

  @override
  void dispose() {
    _settings.removeListener(refresh);
    super.dispose();
  }
}
