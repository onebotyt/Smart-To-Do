import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/lifecycle/resource_manager.dart';
import '../../data/database/projects_database.dart';
import 'agent_orchestrator.dart';
import 'project_graph_service.dart';

class ProjectWorkspacePage extends StatefulWidget {
  final Map<String, dynamic> project;
  final Database projectsDb;

  const ProjectWorkspacePage({
    super.key,
    required this.project,
    required this.projectsDb,
  });

  @override
  State<ProjectWorkspacePage> createState() => _ProjectWorkspacePageState();
}

class _ProjectWorkspacePageState extends State<ProjectWorkspacePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ProjectGraphService _graphService;
  late final AgentOrchestrator _agentOrchestrator;

  ProjectGraphSummary _summary = ProjectGraphSummary.empty();
  bool _isIndexing = false;
  String _indexStatus = '';
  double _indexProgress = 0.0;
  String _searchQuery = '';

  final TextEditingController _taskController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();

  List<Map<String, dynamic>> _sessions = [];
  bool _loadingSessions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _graphService = ProjectGraphService(projectsDb: widget.projectsDb);
    _agentOrchestrator = AgentOrchestrator(projectsDb: widget.projectsDb);

    _agentOrchestrator.addListener(_onAgentUpdate);
    _loadInitialData();
  }

  @override
  void dispose() {
    _agentOrchestrator.removeListener(_onAgentUpdate);
    _agentOrchestrator.dispose();
    _tabController.dispose();
    _taskController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  void _onAgentUpdate() {
    if (mounted) {
      setState(() {});
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _loadInitialData() async {
    final projId = widget.project['id'] as String;
    final summary = await _graphService.loadExistingSummary(projId);
    if (mounted) {
      setState(() => _summary = summary);
    }
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final projId = widget.project['id'] as String;
    setState(() => _loadingSessions = true);
    final sessions = await ProjectsDatabase.listSessions(widget.projectsDb, projId);
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _loadingSessions = false;
      });
    }
  }

  Future<void> _runIndex() async {
    if (_isIndexing) return;
    setState(() {
      _isIndexing = true;
      _indexStatus = 'Starting index...';
      _indexProgress = 0.0;
    });

    try {
      final summary = await _graphService.indexProject(
        projectId: widget.project['id'] as String,
        rootPath: widget.project['root_path'] as String,
        onProgress: (status, progress) {
          if (mounted) {
            setState(() {
              _indexStatus = status;
              _indexProgress = progress;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _summary = summary;
          _isIndexing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isIndexing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Indexing error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resourceMgr = context.watch<ResourceManager>();
    final theme = Theme.of(context);
    final projectName = widget.project['name'] ?? 'Project';
    final rootPath = widget.project['root_path'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(projectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(rootPath, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          // Memory indicator pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.memory_rounded,
                  size: 14,
                  color: resourceMgr.isUnderMemoryPressure ? Colors.orange : const Color(0xFF10B981),
                ),
                const SizedBox(width: 6),
                Text(
                  '${resourceMgr.totalEstimatedMemoryMb} MB / ${ResourceManager.maxWorkerMemoryBudgetMb} MB',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.account_tree_outlined), text: 'Project Graph'),
            Tab(icon: Icon(Icons.hub_outlined), text: 'Agent Runner'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Checkpoints'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGraphTab(context),
          _buildAgentTab(context),
          _buildCheckpointsTab(context),
        ],
      ),
    );
  }

  Widget _buildGraphTab(BuildContext context) {
    final theme = Theme.of(context);
    final visibleFiles = _searchQuery.isEmpty
        ? _summary.topFiles
        : _summary.topFiles.where((f) => (f['path'] as String? ?? '').toLowerCase().contains(_searchQuery)).toList();
    final visibleSymbols = _searchQuery.isEmpty
        ? _summary.sampleSymbols
        : _summary.sampleSymbols.where((s) {
            final name = (s['symbol_name'] as String? ?? '').toLowerCase();
            final path = (s['file_path'] as String? ?? '').toLowerCase();
            return name.contains(_searchQuery) || path.contains(_searchQuery);
          }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Index Action Card
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Workspace Graph & AST Symbols', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Lightweight scanner bounded to protect system memory', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    FilledButton.icon(
                      icon: _isIndexing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.sync_rounded, size: 16),
                      label: Text(_isIndexing ? 'Indexing...' : 'Scan / Re-Index'),
                      onPressed: _isIndexing ? null : _runIndex,
                    ),
                  ],
                ),
                if (_isIndexing) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _indexProgress),
                  const SizedBox(height: 6),
                  Text(_indexStatus, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Statistics Cards
        Row(
          children: [
            Expanded(child: _buildStatTile('Indexed Files', '${_summary.totalFiles}', Icons.insert_drive_file_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatTile('Total Lines', '${_summary.totalLines}', Icons.code_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatTile('Code Symbols', '${_summary.totalSymbols}', Icons.data_object_rounded)),
          ],
        ),
        const SizedBox(height: 16),

        // Symbol & File Search Bar
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search files and code symbols (e.g. Controller, service, main.dart)...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () => setState(() => _searchQuery = ''),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 16),
        // Top Files
        if (visibleFiles.isNotEmpty) ...[
          const Text('Largest Files', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...visibleFiles.map((f) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.article_outlined, size: 18),
                  title: Text(f['path'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  trailing: Text('${f['line_count']} lines', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              )),
        ],

        // Sample Symbols
        if (visibleSymbols.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Sample Indexed Symbols', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _summary.sampleSymbols.map((s) {
              final isClass = s['symbol_type'] == 'class';
              return Chip(
                avatar: Icon(isClass ? Icons.category : Icons.functions, size: 14),
                label: Text('${s['symbol_name']} (${s['file_path']}:${s['line_number']})'),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAgentTab(BuildContext context) {
    final theme = Theme.of(context);
    final isExecuting = _agentOrchestrator.isExecuting;
    final steps = _agentOrchestrator.steps;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prompt & Trigger Card
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taskController,
                  enabled: !isExecuting,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Verify test suite and generate recovery checkpoint',
                    labelText: 'Coding Agent Task',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.psychology_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (isExecuting)
                FilledButton.icon(
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('Abort Agent'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () => _agentOrchestrator.abort(),
                )
              else
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Run Task'),
                  onPressed: () {
                    final task = _taskController.text.trim();
                    if (task.isEmpty) return;
                    _agentOrchestrator.runTask(
                      projectId: widget.project['id'] as String,
                      taskDescription: task,
                      rootPath: widget.project['root_path'] as String,
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Steps Progress
          if (steps.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: steps.map((st) {
                  Color color = Colors.grey;
                  IconData icon = Icons.circle_outlined;
                  if (st.status == 'active') {
                    color = const Color(0xFF6366F1);
                    icon = Icons.motion_photos_on_outlined;
                  } else if (st.status == 'success') {
                    color = const Color(0xFF10B981);
                    icon = Icons.check_circle_rounded;
                  } else if (st.status == 'failed') {
                    color = Colors.redAccent;
                    icon = Icons.error_outline;
                  } else if (st.status == 'cancelled') {
                    color = Colors.orange;
                    icon = Icons.cancel_outlined;
                  }
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: color),
                        const SizedBox(width: 6),
                        Text(
                          st.title,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Console Terminal Output
          const Text('Execution & Verification Log', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: _agentOrchestrator.logs.isEmpty
                  ? const Center(
                      child: Text(
                        'Ready. Enter a task and click Run Task to initiate.',
                        style: TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      controller: _logScrollController,
                      itemCount: _agentOrchestrator.logs.length,
                      itemBuilder: (ctx, idx) {
                        final line = _agentOrchestrator.logs[idx];
                        Color textColor = const Color(0xFFE2E8F0);
                        if (line.contains('❌') || line.contains('failed')) textColor = Colors.redAccent;
                        if (line.contains('⚠️')) textColor = Colors.amberAccent;
                        if (line.contains('✅') || line.contains('success')) textColor = const Color(0xFF4ADE80);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            line,
                            style: TextStyle(color: textColor, fontFamily: 'monospace', fontSize: 11),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckpointsTab(BuildContext context) {
    if (_loadingSessions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sessions.isEmpty) {
      return const Center(
        child: Text('No agent sessions recorded yet.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      itemBuilder: (ctx, idx) {
        final sess = _sessions[idx];
        final title = sess['title'] ?? 'Session';
        final status = sess['status'] ?? 'unknown';
        final startedAt = DateTime.fromMillisecondsSinceEpoch(sess['started_at'] as int);

        Color statusColor = const Color(0xFF10B981);
        if (status == 'failed') statusColor = Colors.redAccent;
        if (status == 'aborted') statusColor = Colors.orange;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Icon(Icons.bookmark_border_rounded, color: statusColor, size: 20),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Status: $status • Started: ${startedAt.toLocal().toString().substring(0, 16)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => _showSessionDetails(context, sess),
          ),
        );
      },
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
  Future<void> _showSessionDetails(BuildContext context, Map<String, dynamic> sess) async {
    final checkpoints = await ProjectsDatabase.listCheckpoints(widget.projectsDb, sess['id'] as String);
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.history_edu_rounded, color: Color(0xFF6366F1), size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(sess['title'] ?? 'Session Details', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${sess['status']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              const Text('Recovery Checkpoints:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              if (checkpoints.isEmpty)
                const Text('No checkpoints saved for this session.', style: TextStyle(color: Colors.grey, fontSize: 12))
              else
                ...checkpoints.map((cp) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Step ${cp['step_index']}: ${cp['summary']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                if (cp['git_commit'] != null)
                                  Text('Commit: ${cp['git_commit']}', style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}