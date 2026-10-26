import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/task.dart';
import '../settings/settings_page.dart';
import 'task_controller.dart';
import 'task_edit_page.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaskController>();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/logo.png', width: 28, height: 28),
            ),
            const SizedBox(width: 10),
            const Text('SyncTask'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search tasks',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: c.setQuery,
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<TaskFilter>(
              segments: const [
                ButtonSegment(
                  value: TaskFilter.all,
                  label: Text('All'),
                  icon: Icon(Icons.list),
                ),
                ButtonSegment(
                  value: TaskFilter.pending,
                  label: Text('Pending'),
                  icon: Icon(Icons.pending_actions),
                ),
                ButtonSegment(
                  value: TaskFilter.completed,
                  label: Text('Completed'),
                  icon: Icon(Icons.task_alt),
                ),
              ],
              selected: {c.filter},
              onSelectionChanged: (selected) => c.setFilter(selected.first),
            ),
          ),
          if (c.categories.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          const Divider(height: 1),
          Expanded(
            child: c.tasks.isEmpty
                ? const Center(child: Text('No tasks found. Tap + to add one.'))
                : ListView.builder(
                    itemCount: c.tasks.length,
                    itemBuilder: (context, i) => _TaskTile(task: c.tasks[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TaskEditPage())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});
  final Task task;

  static const _colors = [Colors.grey, Colors.blue, Colors.red];

  @override
  Widget build(BuildContext context) {
    final c = context.read<TaskController>();
    final parts = <String>[
      if (task.category.isNotEmpty) task.category,
      if (task.dueAt != null)
        'Due ${DateTime.fromMillisecondsSinceEpoch(task.dueAt!, isUtc: true).toLocal().toString().substring(0, 16)}',
      if (task.recurrence != Recurrence.none) task.recurrence.name,
    ];
    return Dismissible(
      key: ValueKey(task.id),
      background: Container(color: Colors.red),
      onDismissed: (_) => c.remove(task),
      child: ListTile(
        leading: Checkbox(value: task.completed, onChanged: (_) => c.toggle(task)),
        title: Text(
          task.title,
          style: task.completed
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: parts.isEmpty ? null : Text(parts.join(' · ')),
        trailing: Icon(Icons.flag, color: _colors[task.priority]),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => TaskEditPage(task: task))),
      ),
    );
  }
}
