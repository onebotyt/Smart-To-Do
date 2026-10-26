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
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _category;
  late int _priority;
  late Recurrence _recurrence;
  DateTime? _due;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _notes = TextEditingController(text: t?.notes ?? '');
    _category = TextEditingController(text: t?.category ?? '');
    _priority =
        t?.priority ?? context.read<SettingsController>().defaultPriority;
    _recurrence = t?.recurrence ?? Recurrence.none;
    _due = t?.dueAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(t!.dueAt!, isUtc: true).toLocal();
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _category.dispose();
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
    if (!_form.currentState!.validate()) return;
    final c = context.read<TaskController>();
    final dueMs = _due?.toUtc().millisecondsSinceEpoch;
    final existing = widget.task;
    if (existing == null) {
      await c.add(
        title: _title.text,
        notes: _notes.text,
        dueAt: dueMs,
        priority: _priority,
        category: _category.text,
        recurrence: _recurrence,
      );
    } else {
      await c.save(existing.copyWith(
        title: _title.text.trim(),
        notes: _notes.text,
        dueAt: dueMs,
        clearDueAt: dueMs == null,
        priority: _priority,
        category: _category.text.trim(),
        recurrence: _recurrence,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'New task' : 'Edit task'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_due == null
                  ? 'No due date'
                  : _due.toString().substring(0, 16)),
              trailing: Wrap(children: [
                if (_due != null)
                  IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _due = null)),
                IconButton(icon: const Icon(Icons.event), onPressed: _pickDue),
              ]),
            ),
            DropdownButtonFormField<int>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Low')),
                DropdownMenuItem(value: 1, child: Text('Normal')),
                DropdownMenuItem(value: 2, child: Text('High')),
              ],
              onChanged: (v) => setState(() => _priority = v ?? 1),
            ),
            DropdownButtonFormField<Recurrence>(
              initialValue: _recurrence,
              decoration: const InputDecoration(labelText: 'Repeat'),
              items: Recurrence.values
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                  .toList(),
              onChanged: (v) => setState(() => _recurrence = v ?? Recurrence.none),
            ),
          ],
        ),
      ),
    );
  }
}
