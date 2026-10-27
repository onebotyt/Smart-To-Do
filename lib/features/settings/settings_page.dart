import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../platform/floating_panel_service.dart';
import '../../platform/update_service.dart';
import '../../platform/window_service.dart';
import '../clipboard/clipboard_controller.dart';
import '../floating_panel/floating_task_panel.dart';
import '../sync/devices_page.dart';
import '../update/update_dialog.dart';
import '../sky/widgets/sky_mascot_widget.dart';
import 'settings_controller.dart';
import 'widgets/diagnostic_log_sheet.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            children: [
              const _Header('Sync & Devices'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.devices, color: Colors.blue),
                  title: const Text('Paired Devices & Wi-Fi Sync'),
                  subtitle: const Text('Direct device-to-device synchronization'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DevicesPage()),
                  ),
                ),
              ),

              const _Header('Appearance & Color Themes'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mode Selector (System, Light, Dark)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Theme Mode', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                          DropdownButton<ThemeMode>(
                            value: s.themeMode,
                            underline: const SizedBox(),
                            onChanged: (m) => m == null ? null : s.setThemeMode(m),
                            items: const [
                              DropdownMenuItem(value: ThemeMode.system, child: Text('System Default')),
                              DropdownMenuItem(value: ThemeMode.light, child: Text('Light Mode')),
                              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark Mode')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Accent Color Palette
                      const Text(
                        'Accent Color Theme',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: List.generate(
                          SettingsController.themePalette.length,
                          (index) {
                            final color = SettingsController.themePalette[index];
                            final isSelected = s.themeColorIndex == index;
                            final name = SettingsController.themeColorNames[index];

                            return Tooltip(
                              message: name,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => s.setThemeColorIndex(index),
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutBack,
                                  scale: isSelected ? 1.08 : 0.94,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutCubic,
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? Colors.white : Colors.transparent,
                                        width: isSelected ? 3 : 0,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: color.withValues(alpha: 0.6),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // AMOLED Pure Black Option
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('AMOLED Pure Black (Dark Mode)'),
                        subtitle: const Text('Pitch black background for OLED screens & battery saving'),
                        value: s.isAmoledDark,
                        onChanged: s.setAmoledDark,
                      ),
                    ],
                  ),
                ),
              ),

              const _Header('Productivity & Floating Controls'),
              Card(
                child: Column(
                  children: [
                    // Floating Screen / Desktop Bubble Toggle
                    SwitchListTile(
                      secondary: const Icon(Icons.bubble_chart, color: Colors.indigo),
                      title: Text(
                        Platform.isWindows
                            ? 'Desktop Floating Bubble'
                            : 'Floating Screen Bubble',
                      ),
                      subtitle: Text(
                        Platform.isWindows
                            ? 'Floating circular bubble on PC desktop that stays on top of all apps'
                            : 'Show quick-access floating bubble over other apps',
                      ),
                      value: s.isFloatingBubbleEnabled,
                      onChanged: (val) async {
                        s.setFloatingBubbleEnabled(val);
                        if (val && Platform.isWindows) {
                          PlatformWindowService.setWindowMode(AppWindowMode.bubble);
                        } else if (val && Platform.isAndroid) {
                          final service = PlatformFloatingPanelService();
                          final hasPerm = await service.hasPermission();
                          if (!hasPerm && context.mounted) {
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                icon: const Icon(Icons.layers_outlined, size: 36, color: Colors.blueAccent),
                                title: const Text('Overlay Permission Needed'),
                                content: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'To show the floating bubble over other apps, Android requires the "Display over other apps" permission.',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      '⚠️ If you see "Access denied for this app" (Restricted setting):',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      '1. Tap "Open App Info (Unblock)" below.\n'
                                      '2. Tap the three dots (⋮) in the top-right corner.\n'
                                      '3. Tap "Allow restricted settings".\n'
                                      '4. Then turn on "Allow display over other apps".',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      service.openAppSettings();
                                    },
                                    child: const Text('Open App Info (Unblock)'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      service.requestPermission();
                                    },
                                    child: const Text('Open Overlay Settings'),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(height: 1),

                    // Always On Top Toggle (Floating panel and bubble only - Desktop)
                    if (Platform.isWindows) ...[
                      SwitchListTile(
                        secondary: const Icon(Icons.push_pin_outlined, color: Colors.blueAccent),
                        title: const Text('Keep Floating Panel Always On Top'),
                        subtitle: const Text('Floating panel and bubble stay above other apps (main app stays normal)'),
                        value: s.isAlwaysOnTop,
                        onChanged: s.setAlwaysOnTop,
                      ),
                      const Divider(height: 1),
                    ],

                    // Floating Panel Window Launcher
                    const _FloatingPanelTile(),
                    const Divider(height: 1),

                    // Android Home-Screen Widget Guide (Android only)
                    if (Platform.isAndroid) ...[
                      const _WidgetTile(),
                      const Divider(height: 1),
                    ],

                    // Launch at Startup
                    const _StartupTile(),
                  ],
                ),
              ),

              const _Header('Universal Clipboard Sharing'),
              const Card(child: _ClipboardSyncTile()),

              const _Header('Tasks Preferences'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Show completed tasks in main list'),
                      value: s.showCompleted,
                      onChanged: s.setShowCompleted,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Default task priority'),
                      trailing: DropdownButton<int>(
                        value: s.defaultPriority,
                        underline: const SizedBox(),
                        onChanged: (v) => v == null ? null : s.setDefaultPriority(v),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Low (Green)')),
                          DropdownMenuItem(value: 1, child: Text('Normal (Amber)')),
                          DropdownMenuItem(value: 2, child: Text('High (Red)')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const _Header('App Updates'),
              const Card(child: _UpdateTile()),

              const _Header('Diagnostics & GitHub Support'),
              const Card(child: _DiagnosticsTile()),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingPanelTile extends StatelessWidget {
  const _FloatingPanelTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.picture_in_picture_alt, color: Colors.blue),
      title: const Text('Floating task panel window'),
      subtitle: const Text('Open compact always-on-top quick checklist'),
      trailing: const Icon(Icons.open_in_new, size: 20),
      onTap: () async {
        if (Platform.isWindows) {
          await PlatformWindowService.setWindowMode(AppWindowMode.panel);
        } else {
          final service = PlatformFloatingPanelService();
          final hasPerm = await service.hasPermission();
          if (!hasPerm && context.mounted) {
            await service.requestPermission();
          }
          if (context.mounted) {
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
        }
      },
    );
  }
}

class _WidgetTile extends StatelessWidget {
  const _WidgetTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.widgets_outlined, color: Colors.teal),
      title: const Text('Home-screen widget (Android)'),
      subtitle: const Text('Native Android widget with live pending tasks'),
      trailing: const Icon(Icons.info_outline, size: 20),
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Add Home-Screen Widget'),
            content: const Text(
              'To add the SyncTask widget:\n\n'
              '1. Long-press any empty space on your Android home screen.\n'
              '2. Select "Widgets".\n'
              '3. Scroll to "SyncTask" and drag the widget to your home screen.\n\n'
              'The widget updates automatically whenever tasks change!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StartupTile extends StatelessWidget {
  const _StartupTile();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();

    final title = Platform.isWindows
        ? 'Launch at startup (Windows)'
        : (Platform.isAndroid
            ? 'Auto-start on device boot (Android)'
            : 'Launch at startup');

    final subtitle = Platform.isWindows
        ? 'Start SyncTask automatically when PC boots up'
        : (Platform.isAndroid
            ? 'Refresh home widget & sync tasks when phone starts'
            : 'Start SyncTask automatically in background');

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.rocket_launch_outlined, color: Colors.deepOrange),
          title: Text(title),
          subtitle: Text(subtitle),
          value: s.isLaunchAtStartup,
          onChanged: s.setLaunchAtStartup,
        ),
        if (s.isLaunchAtStartup && Platform.isWindows)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: SwitchListTile(
              secondary: const Icon(Icons.bubble_chart_outlined, color: Colors.indigo),
              title: const Text('Start as Desktop Floating Bubble'),
              subtitle: const Text('Directly launch as the floating bubble on PC startup'),
              value: s.isStartInBubbleMode,
              onChanged: s.setStartInBubbleMode,
            ),
          ),
      ],
    );
  }
}

class _ClipboardSyncTile extends StatelessWidget {
  const _ClipboardSyncTile();

  @override
  Widget build(BuildContext context) {
    ClipboardController? clip;
    try {
      clip = context.watch<ClipboardController>();
    } catch (_) {
      clip = null;
    }

    if (clip == null) {
      return const ListTile(
        title: Text('Universal clipboard'),
        subtitle: Text('Plain-text sharing across devices'),
      );
    }

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.content_paste_go_outlined, color: Colors.purple),
          title: const Text('Universal clipboard'),
          subtitle: Text(
            clip.isEnabled
                ? (clip.isPaused
                    ? 'Paused • Not sharing copied text'
                    : 'Active • Text copies sync between trusted devices')
                : 'Disabled • Opt-in to share copied text',
          ),
          value: clip.isEnabled,
          onChanged: clip.setEnabled,
        ),
        if (clip.isEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(68, 0, 16, 12),
            child: Row(
              children: [
                OutlinedButton.icon(
                  icon: Icon(
                    clip.isPaused ? Icons.play_arrow : Icons.pause,
                    size: 16,
                  ),
                  label: Text(clip.isPaused ? 'Resume sync' : 'Pause sync'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => clip!.setPaused(!clip.isPaused),
                ),
                const SizedBox(width: 10),
                Text(
                  'Plain text only • Loop protected',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _UpdateTile extends StatefulWidget {
  const _UpdateTile();

  @override
  State<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<_UpdateTile> {
  final _service = GitHubUpdateService();
  String? _statusMessage;
  bool _isChecking = false;
  AppRelease? _foundRelease;

  Future<void> _check() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'Checking for updates...';
      _foundRelease = null;
    });

    final release = await _service.checkForUpdate();
    if (!mounted) return;

    if (release != null) {
      setState(() {
        _isChecking = false;
        _statusMessage = 'New version available: ${release.versionTag}!';
        _foundRelease = release;
      });
      // Automatically prompt the animated update dialog
      UpdateDownloadDialog.show(context, release);
    } else {
      setState(() {
        _isChecking = false;
        _statusMessage = "You're on the latest version! 🎉";
        _foundRelease = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        alignment: Alignment.center,
        child: const ClipOval(
          child: SkyMascotWidget(size: 28),
        ),
      ),
      title: const Text('SyncTask Updates', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(_statusMessage ?? 'Tap "Check now" to look for new updates'),
      trailing: _isChecking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (_foundRelease != null
              ? FilledButton.icon(
                  icon: const Icon(Icons.rocket_launch, size: 16),
                  label: const Text('Update Now'),
                  onPressed: () => UpdateDownloadDialog.show(context, _foundRelease!),
                )
              : OutlinedButton(
                  onPressed: _check,
                  child: const Text('Check now'),
                )),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
}

class _DiagnosticsTile extends StatelessWidget {
  const _DiagnosticsTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.blueGrey.withValues(alpha: 0.15),
        ),
        child: const Icon(Icons.receipt_long_outlined, color: Colors.blueGrey, size: 20),
      ),
      title: const Text('Diagnostics & Action Logs'),
      subtitle: const Text('View real-time event logs & send diagnostic reports to GitHub'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => showDiagnosticLogsModal(context),
    );
  }
}
