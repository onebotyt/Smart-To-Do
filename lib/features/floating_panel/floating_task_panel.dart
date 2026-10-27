import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:synctask/data/models/task.dart';
import 'package:synctask/features/sync/sync_controller.dart';
import 'package:synctask/features/tasks/task_controller.dart';
import '../../platform/window_service.dart';
import '../settings/settings_controller.dart';

class FloatingTaskPanel extends StatefulWidget {
  final VoidCallback? onClose;
  final VoidCallback? onExpand;
  final double? width;
  final double? height;

  const FloatingTaskPanel({
    super.key,
    this.onClose,
    this.onExpand,
    this.width,
    this.height,
  });

  @override
  State<FloatingTaskPanel> createState() => _FloatingTaskPanelState();
}

class _FloatingTaskPanelState extends State<FloatingTaskPanel> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedPriority = 1; // Normal
  bool _onlyPending = true;

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitTask() async {
    final title = _inputController.text.trim();
    if (title.isEmpty) return;

    final controller = context.read<TaskController>();
    await controller.create(
      title: title,
      priority: _selectedPriority,
    );

    _inputController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final taskController = context.watch<TaskController>();
    final syncController = context.watch<SyncController>();
    final settings = context.watch<SettingsController?>();

    final allTasks = taskController.tasks;
    final filteredTasks = _onlyPending
        ? allTasks.where((t) => !t.completed).toList()
        : allTasks;
    final pendingCount = allTasks.where((t) => !t.completed).length;

    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Panel Header (Draggable visual bar)
              GestureDetector(
                onPanStart: (_) {
                  if (Platform.isWindows) {
                    PlatformWindowService.startDragging();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                    ClipOval(
                      child: Image.asset('assets/logo.png', width: 20, height: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SyncTask',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Quick Sync Button
                    if (syncController.isSyncing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.sync, size: 18),
                        tooltip: 'Sync now',
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await syncController.syncAll();
                          if (context.mounted) {
                            taskController.refresh();
                          }
                        },
                      ),
                    if (settings != null)
                      IconButton(
                        icon: Icon(
                          settings.isAlwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined,
                          size: 16,
                          color: settings.isAlwaysOnTop ? theme.colorScheme.primary : null,
                        ),
                        tooltip: settings.isAlwaysOnTop
                            ? 'Pinned on top of all apps'
                            : 'Pin on top of all apps',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => settings.setAlwaysOnTop(!settings.isAlwaysOnTop),
                      ),
                    if (widget.onExpand != null)
                      IconButton(
                        icon: const Icon(Icons.open_in_full, size: 16),
                        tooltip: 'Open main app',
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onExpand,
                      ),
                    // Options menu (Close Bubble, Open App, Exit)
                    PopupMenuButton<String>(
                      tooltip: 'Bubble Options',
                      icon: const Icon(Icons.more_vert, size: 18),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        if (val == 'open_app') {
                          if (widget.onExpand != null) {
                            widget.onExpand!();
                          } else if (Platform.isWindows) {
                            PlatformWindowService.setWindowMode(AppWindowMode.normal);
                          }
                        } else if (val == 'close_bubble') {
                          if (Platform.isWindows) {
                            PlatformWindowService.setWindowMode(AppWindowMode.normal);
                          } else {
                            settings?.setFloatingBubbleEnabled(false);
                            widget.onClose?.call();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Floating bubble hidden. Re-enable anytime in Settings.'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        } else if (val == 'exit_app') {
                          PlatformWindowService.exitApp();
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'open_app',
                          child: Row(
                            children: [
                              Icon(Icons.open_in_full, size: 18),
                              SizedBox(width: 8),
                              Text('Open Full App'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'close_bubble',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_off_outlined, size: 18, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Close Floating Bubble'),
                            ],
                          ),
                        ),
                        if (Platform.isWindows) ...[
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'exit_app',
                            child: Row(
                              children: [
                                Icon(Icons.power_settings_new, size: 18, color: Colors.redAccent),
                                SizedBox(width: 8),
                                Text('Exit App', style: TextStyle(color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Collapse to bubble',
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onClose,
                      ),
                  ],
                ),
              ),
            ),

              // Quick Input Box
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Row(
                  children: [
                    // Priority Indicator / Selector
                    PopupMenuButton<int>(
                      tooltip: 'Priority',
                      initialValue: _selectedPriority,
                      onSelected: (p) => setState(() => _selectedPriority = p),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.flag,
                          size: 18,
                          color: _priorityColor(_selectedPriority),
                        ),
                      ),
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 2, child: Text('High Priority (Red)')),
                        PopupMenuItem(value: 1, child: Text('Normal Priority (Orange)')),
                        PopupMenuItem(value: 0, child: Text('Low Priority (Green)')),
                      ],
                    ),
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitTask(),
                        decoration: const InputDecoration(
                          hintText: 'Add quick task...',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                      visualDensity: VisualDensity.compact,
                      onPressed: _submitTask,
                    ),
                  ],
                ),
              ),

              // Filter row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Pending only', style: TextStyle(fontSize: 11)),
                      selected: _onlyPending,
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) => setState(() => _onlyPending = val),
                    ),
                    const Spacer(),
                    Text(
                      '${filteredTasks.length} tasks',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Divider(height: 8),

              // Task Checklist
              Expanded(
                child: filteredTasks.isEmpty
                    ? Center(
                        child: Text(
                          _onlyPending ? 'All caught up! 🎉' : 'No tasks yet',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: filteredTasks.length,
                        itemBuilder: (context, index) {
                          final task = filteredTasks[index];
                          return _buildTaskRow(taskController, task);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskRow(TaskController controller, Task task) {
    return InkWell(
      onTap: () => controller.toggleComplete(task),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: task.completed,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => controller.toggleComplete(task),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _priorityColor(task.priority),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  decoration: task.completed ? TextDecoration.lineThrough : null,
                  color: task.completed ? Colors.grey : null,
                ),
              ),
            ),
            if (task.dueAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  _formatDueDate(task.dueAt!),
                  style: TextStyle(
                    fontSize: 10,
                    color: _isOverdue(task.dueAt!) ? Colors.red : Colors.grey,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete task',
              onPressed: () => controller.remove(task),
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(int priority) {
    switch (priority) {
      case 2:
        return Colors.red;
      case 1:
        return Colors.amber;
      case 0:
      default:
        return Colors.green;
    }
  }

  String _formatDueDate(int dueMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(dueMs);
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    return '${date.month}/${date.day}';
  }

  bool _isOverdue(int dueMs) {
    return dueMs < DateTime.now().millisecondsSinceEpoch;
  }
}
