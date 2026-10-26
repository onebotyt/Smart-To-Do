import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/task.dart';
import '../settings/settings_controller.dart';
import 'task_controller.dart';

class TaskEditPage extends StatefulWidget {
  const TaskEditPage({super.key, this.task});
  final Task? task;

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _noteController;
  late final TextEditingController _categoryController;
  late int _priority;
  late Recurrence _recurrence;
  DateTime? _due;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    // Note-first: if notes exist, use notes; otherwise use title
    final initialNote = t != null
        ? (t.notes.isNotEmpty ? t.notes : t.title)
        : '';

    _noteController = TextEditingController(text: initialNote);
    _categoryController = TextEditingController(text: t?.category ?? '');
    _priority =
        t?.priority ?? context.read<SettingsController>().defaultPriority;
    _recurrence = t?.recurrence ?? Recurrence.none;
    _due = t?.dueAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(t!.dueAt!, isUtc: true).toLocal();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due ?? now),
    );
    if (t == null) return;
    setState(() => _due = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    final rawText = _noteController.text.trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a note for this task')),
      );
      return;
    }

    final c = context.read<TaskController>();
    final dueMs = _due?.toUtc().millisecondsSinceEpoch;

    // Use the first non-empty line as title (up to 80 chars), and the full content as notes
    final lines = rawText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final title = lines.isNotEmpty
        ? (lines.first.length > 80 ? '${lines.first.substring(0, 77)}...' : lines.first)
        : rawText;
    final notes = rawText;

    final existing = widget.task;
    if (existing == null) {
      await c.add(
        title: title,
        notes: notes,
        dueAt: dueMs,
        priority: _priority,
        category: _categoryController.text.trim(),
        recurrence: _recurrence,
      );
    } else {
      await c.save(existing.copyWith(
        title: title,
        notes: notes,
        dueAt: dueMs,
        clearDueAt: dueMs == null,
        priority: _priority,
        category: _categoryController.text.trim(),
        recurrence: _recurrence,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.task == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New Task' : 'Edit Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Note Card (Single unified note input)
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Task Note',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _noteController,
                          autofocus: true,
                          maxLines: 5,
                          minLines: 3,
                          style: const TextStyle(fontSize: 16),
                          decoration: const InputDecoration(
                            hintText: 'What do you need to do? Write your note here...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Details Card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Priority Selector
                        Text('Priority', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildPriorityChip(0, 'Low', Colors.green),
                            const SizedBox(width: 8),
                            _buildPriorityChip(1, 'Normal', Colors.amber),
                            const SizedBox(width: 8),
                            _buildPriorityChip(2, 'High', Colors.red),
                          ],
                        ),
                        const Divider(height: 28),

                        // Due Date Selector
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _due == null
                                    ? 'No due date'
                                    : 'Due: ${_due.toString().substring(0, 16)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            if (_due != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() => _due = null),
                              ),
                            FilledButton.tonal(
                              onPressed: _pickDue,
                              child: Text(_due == null ? 'Set Due Date' : 'Change'),
                            ),
                          ],
                        ),
                        const Divider(height: 28),

                        // Recurrence Selector
                        Row(
                          children: [
                            Icon(Icons.repeat, size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 10),
                            const Text('Repeat', style: TextStyle(fontSize: 14)),
                            const Spacer(),
                            DropdownButton<Recurrence>(
                              value: _recurrence,
                              underline: const SizedBox(),
                              items: Recurrence.values
                                  .map((r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(
                                          r == Recurrence.none
                                              ? 'Does not repeat'
                                              : (r == Recurrence.daily ? 'Daily' : 'Weekly'),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _recurrence = v ?? Recurrence.none),
                            ),
                          ],
                        ),
                        const Divider(height: 28),

                        // Category
                        TextFormField(
                          controller: _categoryController,
                          decoration: InputDecoration(
                            labelText: 'Category (Optional)',
                            hintText: 'e.g. Work, Personal, Shopping',
                            prefixIcon: const Icon(Icons.label_outline, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save Action Button
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: Text(isNew ? 'Create Task' : 'Save Changes'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip(int priority, String label, Color color) {
    final selected = _priority == priority;
    return ChoiceChip(
      selected: selected,
      avatar: Icon(Icons.flag, size: 16, color: color),
      label: Text(label),
      onSelected: (_) => setState(() => _priority = priority),
    );
  }
}
