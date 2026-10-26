import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../platform/floating_panel_service.dart';
import '../../platform/startup_service.dart';
import '../../platform/update_service.dart';
import '../clipboard/clipboard_controller.dart';
import '../floating_panel/floating_task_panel.dart';
import '../sync/devices_page.dart';
import '../update/update_dialog.dart';
import 'settings_controller.dart';

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
                    // Floating Screen Bubble Toggle
                    SwitchListTile(
                      secondary: const Icon(Icons.bubble_chart, color: Colors.indigo),
                      title: const Text('Floating Screen Bubble'),
                      subtitle: const Text('Show round draggable icon on screen in PC and mobile'),
                      value: s.isFloatingBubbleEnabled,
                      onChanged: s.setFloatingBubbleEnabled,
                    ),
                    const Divider(height: 1),

                    // Always On Top Toggle (Stay above other apps)
                    SwitchListTile(
                      secondary: const Icon(Icons.push_pin_outlined, color: Colors.blueAccent),
                      title: const Text('Always On Top (Stay Above All Apps)'),
                      subtitle: const Text('Keep window floating over browser, games, and other apps'),
                      value: s.isAlwaysOnTop,
                      onChanged: s.setAlwaysOnTop,
                    ),
                    const Divider(height: 1),

                    // Floating Panel Window Launcher
                    const _FloatingPanelTile(),
                    const Divider(height: 1),

                    // Android Home-Screen Widget Guide
                    const _WidgetTile(),
                    const Divider(height: 1),

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
    final service = PlatformFloatingPanelService();
    return ListTile(
      leading: const Icon(Icons.picture_in_picture_alt, color: Colors.blue),
      title: const Text('Floating task panel window'),
      subtitle: const Text('Open compact always-on-top quick checklist'),
      trailing: const Icon(Icons.open_in_new, size: 20),
      onTap: () async {
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

class _StartupTile extends StatefulWidget {
  const _StartupTile();

  @override
  State<_StartupTile> createState() => _StartupTileState();
}

class _StartupTileState extends State<_StartupTile> {
  final _service = PlatformStartupService();
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final val = await _service.isLaunchAtStartupEnabled();
    if (mounted) setState(() => _enabled = val);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.rocket_launch_outlined, color: Colors.deepOrange),
      title: const Text('Launch at startup (Windows)'),
      subtitle: const Text('Start SyncTask automatically in background'),
      value: _enabled,
      onChanged: (val) async {
        setState(() => _enabled = val);
        await _service.setLaunchAtStartup(val);
      },
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/logo.png', width: 28, height: 28),
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
