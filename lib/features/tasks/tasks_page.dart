import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/task.dart';
import '../../platform/update_service.dart';
import '../floating_panel/floating_task_panel.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_page.dart';
import '../sync/devices_page.dart';
import '../update/update_dialog.dart';
import 'task_controller.dart';
import 'task_edit_page.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  AppRelease? _availableUpdate;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      final updateService = GitHubUpdateService();
      final release = await updateService.checkForUpdate();
      if (mounted && release != null) {
        setState(() => _availableUpdate = release);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaskController>();
    final settings = context.watch<SettingsController>();
    final theme = Theme.of(context);

    final allTasks = c.tasks;
    final allCount = allTasks.length;
    final pendingCount = allTasks.where((t) => !t.completed).length;
    final completedCount = allTasks.where((t) => t.completed).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/logo.png', width: 30, height: 30),
            ),
            const SizedBox(width: 10),
            const Text(
              'SyncTask',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Floating Panel Toggle
          IconButton(
            icon: Icon(
              settings.isFloatingBubbleEnabled
                  ? Icons.bubble_chart
                  : Icons.bubble_chart_outlined,
              color: settings.isFloatingBubbleEnabled
                  ? theme.colorScheme.primary
                  : null,
            ),
            tooltip: settings.isFloatingBubbleEnabled
                ? 'Floating screen bubble: ON'
                : 'Floating screen bubble: OFF',
            onPressed: () {
              final next = !settings.isFloatingBubbleEnabled;
              settings.setFloatingBubbleEnabled(next);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(next
                      ? 'Floating bubble enabled on screen'
                      : 'Floating bubble hidden'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt_outlined),
            tooltip: 'Floating Panel Window',
            onPressed: () {
              showDialog(
                context: context,
                barrierColor: Colors.black38,
                builder: (ctx) => Center(
                  child: FloatingTaskPanel(
                    onClose: () => Navigator.pop(ctx),
                    onExpand: () => Navigator.pop(ctx),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.devices),
            tooltip: 'Devices & Sync',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DevicesPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search tasks or notes...',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: c.setQuery,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // In-App Update Banner if update available
              if (_availableUpdate != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.rocket_launch, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update Available: ${_availableUpdate!.versionTag}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const Text(
                              'New features and performance improvements are ready.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => UpdateDownloadDialog.show(context, _availableUpdate!),
                        child: const Text('Update Now'),
                      ),
                    ],
                  ),
                ),

              // Responsive Filter Row (Fixes text wrapping on mobile)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Row(
                  children: [
                    _buildFilterPill(
                      context,
                      label: 'All ($allCount)',
                      filter: TaskFilter.all,
                      active: c.filter == TaskFilter.all,
                      onTap: () => c.setFilter(TaskFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      context,
                      label: 'Pending ($pendingCount)',
                      filter: TaskFilter.pending,
                      active: c.filter == TaskFilter.pending,
                      onTap: () => c.setFilter(TaskFilter.pending),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      context,
                      label: 'Done ($completedCount)',
                      filter: TaskFilter.completed,
                      active: c.filter == TaskFilter.completed,
                      onTap: () => c.setFilter(TaskFilter.completed),
                    ),
                  ],
                ),
              ),

              // Categories row
              if (c.categories.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('All Categories'),
                          selected: c.selectedCategory == null,
                          onSelected: (selected) {
                            if (selected) c.setSelectedCategory(null);
                          },
                        ),
                      ),
                      ...c.categories.map((cat) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: c.selectedCategory == cat,
                              onSelected: (selected) {
                                c.setSelectedCategory(selected ? cat : null);
                              },
                            ),
                          )),
                    ],
                  ),
                ),

              const SizedBox(height: 6),

              // Task List
              Expanded(
                child: c.tasks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.task_outlined,
                                size: 64,
                                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                c.filter == TaskFilter.completed
                                    ? 'No completed tasks yet'
                                    : 'All caught up!',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                c.filter == TaskFilter.completed
                                    ? 'Completed tasks will appear here.'
                                    : 'Tap the + button to write your first task.',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              if (c.filter != TaskFilter.completed)
                                FilledButton.tonalIcon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Task'),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const TaskEditPage()),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: c.tasks.length,
                        itemBuilder: (context, i) => _TaskCard(task: c.tasks[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TaskEditPage()),
        ),
      ),
    );
  }

  Widget _buildFilterPill(
    BuildContext context, {
    required String label,
    required TaskFilter filter,
    required bool active,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});
  final Task task;

  static const _priorityColors = [Colors.green, Colors.amber, Colors.red];

  @override
  Widget build(BuildContext context) {
    final c = context.read<TaskController>();
    final theme = Theme.of(context);

    final priorityColor = _priorityColors[task.priority.clamp(0, 2)];

    return Dismissible(
      key: ValueKey(task.id),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => c.remove(task),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TaskEditPage(task: task)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Completion Checkbox
                Checkbox(
                  value: task.completed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  onChanged: (_) => c.toggle(task),
                ),

                // Priority Indicator
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),

                // Task content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.notes.isNotEmpty ? task.notes : task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: task.completed ? TextDecoration.lineThrough : null,
                          color: task.completed ? Colors.grey : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (task.category.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                task.category,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (task.dueAt != null) ...[
                            Icon(
                              Icons.event,
                              size: 13,
                              color: _isOverdue(task.dueAt!) ? Colors.red : Colors.grey,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _formatDueDate(task.dueAt!),
                              style: TextStyle(
                                fontSize: 11,
                                color: _isOverdue(task.dueAt!) ? Colors.red : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (task.recurrence != Recurrence.none) ...[
                            Icon(Icons.repeat, size: 12, color: theme.colorScheme.primary),
                            const SizedBox(width: 3),
                            Text(
                              task.recurrence.name,
                              style: TextStyle(fontSize: 10, color: theme.colorScheme.primary),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _isOverdue(int dueMs) {
    return dueMs < DateTime.now().millisecondsSinceEpoch;
  }

  static String _formatDueDate(int dueMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(dueMs, isUtc: true).toLocal();
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    return '${date.month}/${date.day}';
  }
}
