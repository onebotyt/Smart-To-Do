import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/lifecycle/resource_manager.dart';
import '../../core/lifecycle/resource_state.dart';
import '../../data/database/projects_database.dart';
import 'project_workspace_page.dart';

class StudioDashboardPage extends StatefulWidget {
  final Database projectsDb;

  const StudioDashboardPage({super.key, required this.projectsDb});

  @override
  State<StudioDashboardPage> createState() => _StudioDashboardPageState();
}

class _StudioDashboardPageState extends State<StudioDashboardPage> {
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final list = await ProjectsDatabase.listProjects(widget.projectsDb);
      if (mounted) {
        setState(() {
          _projects = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createProjectDialog() async {
    final nameCtrl = TextEditingController();
    final pathCtrl = TextEditingController(text: Directory.current.path);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Engineering Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                hintText: 'e.g. Backend Microservice',
                prefixIcon: Icon(Icons.folder_special),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathCtrl,
              decoration: const InputDecoration(
                labelText: 'Root Directory',
                prefixIcon: Icon(Icons.folder_open),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ProjectsDatabase.createProject(
                widget.projectsDb,
                name: nameCtrl.text.trim(),
                rootPath: pathCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadProjects();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resourceMgr = context.watch<ResourceManager>();
    final theme = Theme.of(context);
    final activeWorkers = resourceMgr.activeWorkers;
    final totalRam = resourceMgr.totalEstimatedMemoryMb;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF6366F1), width: 1.2),
              ),
              child: const Icon(Icons.auto_awesome, color: Color(0xFF818CF8), size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Engineering Studio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'On-Demand Local Project Orchestrator',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Emergency Unload All Button
          FilledButton.tonalIcon(
            icon: const Icon(Icons.power_settings_new, size: 16, color: Colors.redAccent),
            label: const Text('Unload All AI & Workers'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () async {
              await resourceMgr.stopAllWorkers();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All models unloaded and workers stopped. Memory freed.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Live Resource Monitor Card (Crucial for 8 GB RAM machines)
              _buildResourceMonitor(context, resourceMgr, activeWorkers, totalRam),
              const SizedBox(height: 18),

              // 2. Active Projects & Workflows Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Projects & Workspaces',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Project'),
                    onPressed: _createProjectDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_projects.isEmpty)
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    child: Column(
                      children: [
                        Icon(Icons.terminal_rounded, size: 48, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        const Text(
                          'No Engineering Projects Yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Create or open a project workspace to launch coding agents, build graphs, and run local tasks.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.create_new_folder_outlined),
                          label: const Text('Add Existing Project'),
                          onPressed: _createProjectDialog,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._projects.map((proj) => _buildProjectCard(context, proj)),

              const SizedBox(height: 24),

              // 3. Studio Architecture Tools Grid
              const Text(
                'Studio Capabilities',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: [
                  _buildToolCard(
                    context,
                    icon: Icons.hub_outlined,
                    title: 'Coding Agent Runner',
                    subtitle: 'Executes subagents with isolated git worktrees',
                    color: const Color(0xFF3B82F6),
                  ),
                  _buildToolCard(
                    context,
                    icon: Icons.account_tree_outlined,
                    title: 'RAG & Project Graph',
                    subtitle: 'Bounded AST symbols and contextual indexes',
                    color: const Color(0xFF10B981),
                  ),
                  _buildToolCard(
                    context,
                    icon: Icons.memory_rounded,
                    title: 'Model Lifecycle Gateway',
                    subtitle: 'Idle auto-unload with strict RAM budget enforcement',
                    color: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceMonitor(
    BuildContext context,
    ResourceManager resourceMgr,
    List<WorkerInfo> activeWorkers,
    int totalRam,
  ) {
    final theme = Theme.of(context);
    final isPressure = resourceMgr.isUnderMemoryPressure;
    final progress = (totalRam / ResourceManager.maxWorkerMemoryBudgetMb).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPressure ? Colors.orange : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.speed_rounded,
                    size: 20,
                    color: isPressure ? Colors.orange : const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'System Resource Guard (8 GB Host Safety)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isPressure ? Colors.orange : const Color(0xFF10B981)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${activeWorkers.length} Active Workers',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPressure ? Colors.orange : const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI & Worker RAM Allocated: $totalRam MB',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Text(
                'Budget: ${ResourceManager.maxWorkerMemoryBudgetMb} MB max',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              color: isPressure ? Colors.orange : const Color(0xFF6366F1),
            ),
          ),
          if (activeWorkers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: activeWorkers.map((w) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Colors.transparent,
                    child: Icon(
                      w.isModel ? Icons.psychology : Icons.terminal,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  label: Text('${w.name} (${w.estimatedMemoryMb}MB)'),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => resourceMgr.updateWorkerState(w.id, WorkerState.stopped),
                  deleteIcon: const Icon(Icons.stop, size: 16),
                  deleteButtonTooltipMessage: 'Stop Worker & Free Memory',
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, Map<String, dynamic> proj) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0x1F6366F1),
          child: Icon(Icons.folder, color: Color(0xFF6366F1), size: 20),
        ),
        title: Text(proj['name'] ?? 'Unnamed Project', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(proj['root_path'] ?? '', style: const TextStyle(fontSize: 12)),
        trailing: FilledButton.tonal(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => ProjectWorkspacePage(
                  project: proj,
                  projectsDb: widget.projectsDb,
                ),
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
