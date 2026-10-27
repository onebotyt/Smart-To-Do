import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/task.dart';
import '../../platform/floating_panel_service.dart';
import '../../platform/update_service.dart';
import '../../platform/window_service.dart';
import '../floating_panel/floating_task_panel.dart';
import '../media_transfer/media_sharing_page.dart';
import '../media_transfer/task_attachment_helper.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_page.dart';
import '../sync/devices_page.dart';
import '../sync/sync_controller.dart';
import '../update/update_dialog.dart';
import '../monetization/ad_container_widget.dart';
import 'task_controller.dart';
import 'task_edit_page.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with WidgetsBindingObserver {
  AppRelease? _availableUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForUpdates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Platform.isAndroid) {
        _checkAndroidOverlayPermission();
      }
      _checkPendingAction();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingAction();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkPendingAction() async {
    if (!Platform.isAndroid) return;
    try {
      final action = await PlatformFloatingPanelService().checkPendingAction();
      if (action == 'open_create_task' && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TaskEditPage()),
        );
      }
    } catch (_) {}
  }

  Future<void> _checkAndroidOverlayPermission() async {
    final settings = context.read<SettingsController>();
    if (!settings.isFloatingBubbleEnabled) return;

    final service = PlatformFloatingPanelService();
    final hasPerm = await service.hasPermission();
    if (!hasPerm && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.bubble_chart, size: 40, color: Colors.indigo),
          title: const Text('Enable Floating Bubble'),
          content: const Text(
            'SyncTask can show a floating quick-access to-do bubble over other apps so you never miss a task.\n\n'
            'To enable the floating bubble, please grant "Display over other apps" (Appear on top) permission in Android settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not Now'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Allow Permission'),
              onPressed: () async {
                Navigator.pop(ctx);
                await service.requestPermission();
              },
            ),
          ],
        ),
      );
    }
  }

  Future<void> _checkForUpdates() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
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
    final sync = context.watch<SyncController?>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isConnected = sync?.hasConnectedDevice ?? false;
    final connectedCount = sync?.connectedDeviceCount ?? 0;
    final isSyncing = sync?.isSyncing ?? false;
    final hasDevices = sync?.devices.isNotEmpty ?? false;

    final allTasks = c.tasks;
    final allCount = allTasks.length;
    final pendingCount = allTasks.where((t) => !t.completed).length;
    final completedCount = allTasks.where((t) => t.completed).length;
    final isMobile = MediaQuery.of(context).size.width < 560;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset('assets/logo.png', width: 26, height: 26),
            ),
            const SizedBox(width: 8),
            const Text(
              'SyncTask',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              _buildHeaderConnectionStatus(context, sync, theme),
            ] else if (isConnected) ...[
              const SizedBox(width: 6),
              _buildHeaderConnectionStatus(context, sync, theme, compact: true),
            ],
          ],
        ),
        actions: isMobile
            ? [
                _HeaderActionButton(
                  icon: Icons.swap_horizontal_circle_outlined,
                  tooltip: 'Media & File Sharing',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MediaSharingPage()),
                  ),
                ),
                _HeaderActionButton(
                  icon: Icons.devices,
                  tooltip: 'Devices & Sync',
                  isActive: isConnected,
                  activeColor: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                  activeBackgroundColor: isDark ? const Color(0x2822C55E) : const Color(0x1F16A34A),
                  badge: isConnected
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        )
                      : (hasDevices
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${sync!.devices.length}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DevicesPage()),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'More actions',
                  onSelected: (val) async {
                    if (val == 'bubble') {
                      if (Platform.isWindows) {
                        PlatformWindowService.setWindowMode(AppWindowMode.bubble);
                      } else {
                        final next = !settings.isFloatingBubbleEnabled;
                        settings.setFloatingBubbleEnabled(next);
                        if (next && Platform.isAndroid) {
                          final hasPerm = await PlatformFloatingPanelService().hasPermission();
                          if (!hasPerm && context.mounted) {
                            PlatformFloatingPanelService().requestPermission();
                          }
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(next ? 'Floating bubble enabled' : 'Floating bubble hidden'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    } else if (val == 'panel') {
                      if (Platform.isWindows) {
                        PlatformWindowService.setWindowMode(AppWindowMode.panel);
                      } else {
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
                      }
                    } else if (val == 'sync') {
                      final taskCtrl = context.read<TaskController>();
                      if (sync != null) {
                        await sync.syncAll();
                      }
                      await taskCtrl.refresh();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(sync?.statusMessage ?? 'Tasks refreshed & synced!'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } else if (val == 'settings') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    } else if (val == 'studio') {
                      try {
                        Process.start(
                          Platform.resolvedExecutable,
                          ['--studio'],
                          mode: ProcessStartMode.detached,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Launching AI Engineering Studio in separate process...'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to launch studio: $e'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'bubble',
                      child: Row(
                        children: [
                          Icon(
                            settings.isFloatingBubbleEnabled
                                ? Icons.bubble_chart
                                : Icons.bubble_chart_outlined,
                            size: 20,
                            color: settings.isFloatingBubbleEnabled ? theme.colorScheme.primary : null,
                          ),
                          const SizedBox(width: 12),
                          Text(settings.isFloatingBubbleEnabled
                              ? 'Floating Bubble (Enabled)'
                              : 'Enable Floating Bubble'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'panel',
                      child: Row(
                        children: [
                          Icon(Icons.picture_in_picture_alt_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Floating Quick Panel'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'sync',
                      child: Row(
                        children: [
                          Icon(Icons.sync, size: 20),
                          SizedBox(width: 12),
                          Text('Sync & Refresh'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Settings'),
                        ],
                      ),
                    ),
                    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                      const PopupMenuItem(
                        value: 'studio',
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 20, color: Color(0xFF6366F1)),
                            SizedBox(width: 12),
                            Text('AI Engineering Studio'),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
              ]
            : [
                // Floating Desktop Bubble / Screen Bubble Toggle
          _HeaderActionButton(
            icon: settings.isFloatingBubbleEnabled
                ? Icons.bubble_chart
                : Icons.bubble_chart_outlined,
            tooltip: Platform.isWindows
                ? 'Desktop Floating Bubble (Floats over all apps)'
                : (settings.isFloatingBubbleEnabled
                    ? 'Floating screen bubble: ON'
                    : 'Floating screen bubble: OFF'),
            isActive: settings.isFloatingBubbleEnabled,
            onPressed: () {
              if (Platform.isWindows) {
                PlatformWindowService.setWindowMode(AppWindowMode.bubble);
              } else {
                final next = !settings.isFloatingBubbleEnabled;
                settings.setFloatingBubbleEnabled(next);
                if (next && Platform.isAndroid) {
                  PlatformFloatingPanelService().hasPermission().then((hasPerm) {
                    if (!hasPerm && context.mounted) {
                      PlatformFloatingPanelService().requestPermission();
                    }
                  });
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(next
                        ? 'Floating bubble enabled on screen'
                        : 'Floating bubble hidden'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          _HeaderActionButton(
            icon: Icons.picture_in_picture_alt_outlined,
            tooltip: Platform.isWindows
                ? 'Desktop Floating Task Panel'
                : 'Floating Panel Window',
            onPressed: () {
              if (Platform.isWindows) {
                PlatformWindowService.setWindowMode(AppWindowMode.panel);
              } else {
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
              }
            },
          ),
          _HeaderActionButton(
            icon: Icons.devices,
            tooltip: 'Devices & Sync${connectedCount > 0 ? " ($connectedCount connected)" : ""}',
            isActive: isConnected,
            activeColor: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
            activeBackgroundColor: isDark ? const Color(0x2822C55E) : const Color(0x1F16A34A),
            badge: isConnected
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  )
                : (hasDevices
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${sync!.devices.length}',
                          style: const TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DevicesPage()),
            ),
          ),
          _HeaderActionButton(
            icon: Icons.swap_horizontal_circle_outlined,
            tooltip: 'Media & File Sharing',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MediaSharingPage()),
            ),
          ),
          _HeaderActionButton(
            icon: Icons.sync,
            tooltip: isSyncing ? 'Syncing tasks...' : 'Sync & Refresh tasks',
            isActive: isSyncing,
            isSpinning: isSyncing,
            onPressed: () async {
              final taskCtrl = context.read<TaskController>();
              if (sync != null) {
                await sync.syncAll();
              }
              await taskCtrl.refresh();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(sync?.statusMessage ?? 'Tasks refreshed & synced!'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          _HeaderActionButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            _HeaderActionButton(
              icon: Icons.auto_awesome,
              tooltip: 'Launch AI Engineering Studio (Separate process)',
              onPressed: () {
                try {
                  Process.start(
                    Platform.resolvedExecutable,
                    ['--studio'],
                    mode: ProcessStartMode.detached,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Launching AI Engineering Studio in separate process...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to launch studio: $e'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          const SizedBox(width: 4),
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
                        onPressed: () async {
                          await UpdateDownloadDialog.show(context, _availableUpdate!);
                          if (mounted) setState(() => _availableUpdate = null);
                        },
                        child: const Text('Update Now'),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Dismiss',
                        onPressed: () => setState(() => _availableUpdate = null),
                      ),
                    ],
                  ),
                ),

              // Responsive Filter Row with prominent active states
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFilterPill(
                        context,
                        label: 'All',
                        count: allCount,
                        icon: Icons.layers_rounded,
                        filter: TaskFilter.all,
                        active: c.filter == TaskFilter.all,
                        onTap: () => c.setFilter(TaskFilter.all),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterPill(
                        context,
                        label: 'Pending',
                        count: pendingCount,
                        icon: Icons.pending_actions_rounded,
                        filter: TaskFilter.pending,
                        active: c.filter == TaskFilter.pending,
                        onTap: () => c.setFilter(TaskFilter.pending),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterPill(
                        context,
                        label: 'Done',
                        count: completedCount,
                        icon: Icons.check_circle_rounded,
                        filter: TaskFilter.completed,
                        active: c.filter == TaskFilter.completed,
                        onTap: () => c.setFilter(TaskFilter.completed),
                      ),
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
                          avatar: c.selectedCategory == null
                              ? Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
                              : null,
                          label: const Text('All Categories'),
                          selected: c.selectedCategory == null,
                          selectedColor: theme.colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            fontWeight: c.selectedCategory == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: c.selectedCategory == null
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurface,
                          ),
                          side: BorderSide(
                            color: c.selectedCategory == null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: c.selectedCategory == null ? 1.5 : 1,
                          ),
                          onSelected: (selected) {
                            if (selected) c.setSelectedCategory(null);
                          },
                        ),
                      ),
                      ...c.categories.map((cat) {
                        final isSel = c.selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            avatar: isSel
                                ? Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
                                : null,
                            label: Text(cat),
                            selected: isSel,
                            selectedColor: theme.colorScheme.primaryContainer,
                            labelStyle: TextStyle(
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              color: isSel
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                            ),
                            side: BorderSide(
                              color: isSel
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                              width: isSel ? 1.5 : 1,
                            ),
                            onSelected: (selected) {
                              c.setSelectedCategory(selected ? cat : null);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),

              const SizedBox(height: 6),

              // Task List with smooth AnimatedSwitcher
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: child,
                  ),
                  child: c.tasks.isEmpty
                      ? KeyedSubtree(
                          key: ValueKey('empty_${c.filter}'),
                          child: Center(
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
                          ),
                        )
                      : ListView.builder(
                          key: ValueKey('list_${c.filter}_${c.selectedCategory}'),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: c.tasks.length,
                          itemBuilder: (context, i) {
                            final task = c.tasks[i];
                            return TweenAnimationBuilder<double>(
                              key: ValueKey(task.id),
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 160 + (i < 8 ? i * 20 : 160)),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 8 * (1 - value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: _TaskCard(task: task),
                            );
                          },
                        ),
                ),
              ),
              const ContainerizedAdWidget(isBottomBanner: true),
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

  Widget _buildHeaderConnectionStatus(
    BuildContext context,
    SyncController? sync,
    ThemeData theme, {
    bool compact = false,
  }) {
    if (sync == null) return const SizedBox.shrink();
    if (sync.isSyncing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'Syncing',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (sync.hasConnectedDevice) {
      final isDark = theme.brightness == Brightness.dark;
      final greenColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
      final count = sync.connectedDeviceCount;
      final label = count > 1 ? '$count Online' : (sync.connectedDeviceName ?? 'Connected');

      return Tooltip(
        message: 'Device Connected: ${sync.connectedDeviceName ?? "Local Peer"} (Tap to manage)',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DevicesPage()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x2222C55E) : const Color(0x1816A34A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0x664ADE80) : const Color(0x5516A34A),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: greenColor.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: greenColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: greenColor.withValues(alpha: 0.8),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? 70 : 110),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 9.5 : 10.5,
                      fontWeight: FontWeight.bold,
                      color: greenColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (sync.trustedDevices.isNotEmpty) {
      return Tooltip(
        message: 'No paired devices currently reachable (Tap to view devices)',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DevicesPage()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Offline',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: 'Pair another phone or PC to enable device-to-device sync',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DevicesPage()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_link, size: 12, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                'Pair Device',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(
    BuildContext context, {
    required String label,
    required int count,
    required IconData icon,
    required TaskFilter filter,
    required bool active,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.primary
                : (isDark
                    ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: active ? 1.5 : 1.0,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? Colors.white : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.bold : FontWeight.w600,
                    color: active ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.25)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.white : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;
  final Color? activeColor;
  final Color? activeBackgroundColor;
  final Widget? badge;
  final bool isSpinning;

  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.activeColor,
    this.activeBackgroundColor,
    this.badge,
    this.isSpinning = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveActiveColor = activeColor ?? theme.colorScheme.primary;
    final effectiveActiveBg = activeBackgroundColor ??
        theme.colorScheme.primaryContainer.withValues(alpha: 0.85);

    Widget iconWidget = isSpinning
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: effectiveActiveColor,
            ),
          )
        : Icon(
            icon,
            size: 19,
            color: isActive ? effectiveActiveColor : theme.colorScheme.onSurfaceVariant,
          );

    if (badge != null) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          iconWidget,
          Positioned(
            right: -4,
            top: -4,
            child: badge!,
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 8),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: isActive ? effectiveActiveBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(7.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? effectiveActiveColor.withValues(alpha: 0.5)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                  width: isActive ? 1.4 : 0.8,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: effectiveActiveColor.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: iconWidget,
            ),
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
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        opacity: task.completed ? 0.65 : 1.0,
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
                  // Completion Checkbox with animated scale pop
                  AnimatedScale(
                    duration: const Duration(milliseconds: 150),
                    scale: task.completed ? 1.08 : 1.0,
                    child: Checkbox(
                      value: task.completed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      onChanged: (_) => c.toggle(task),
                    ),
                  ),

                  // Priority Indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: priorityColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Task content with animated text style transition
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          style: TextStyle(
                            fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: task.completed ? TextDecoration.lineThrough : null,
                            decorationColor: Colors.grey,
                            color: task.completed ? Colors.grey : theme.colorScheme.onSurface,
                          ),
                          child: Text(
                            TaskAttachmentHelper.cleanNoteText(
                              task.notes.isNotEmpty ? task.notes : task.title,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...() {
                            final attachments = TaskAttachmentHelper.extractAttachments(task.notes);
                            if (attachments.isEmpty) return <Widget>[];
                            return <Widget>[
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => TaskAttachmentHelper.openAttachment(attachments.first),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.attachment, size: 12, color: theme.colorScheme.primary),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${attachments.length} file${attachments.length > 1 ? 's' : ''}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ];
                          }(),
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

                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                  tooltip: 'Delete task',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Task?'),
                        content: Text('Are you sure you want to delete "${task.title}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      c.remove(task);
                    }
                  },
                ),
              ],
            ),
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
