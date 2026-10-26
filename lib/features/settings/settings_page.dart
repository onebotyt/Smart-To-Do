import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/capabilities.dart';
import '../../platform/floating_panel_service.dart';
import '../../platform/startup_service.dart';
import '../../platform/update_service.dart';
import '../floating_panel/floating_task_panel.dart';
import '../sync/devices_page.dart';
import 'settings_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _Header('Sync & Devices'),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Paired Devices & Wi-Fi Sync'),
            subtitle: const Text('Direct device-to-device synchronization'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DevicesPage()),
            ),
          ),
          const _Header('Appearance'),
          ListTile(
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: s.themeMode,
              onChanged: (m) => m == null ? null : s.setThemeMode(m),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
            ),
          ),
          const _Header('Tasks'),
          SwitchListTile(
            title: const Text('Show completed tasks'),
            value: s.showCompleted,
            onChanged: s.setShowCompleted,
          ),
          ListTile(
            title: const Text('Default priority'),
            trailing: DropdownButton<int>(
              value: s.defaultPriority,
              onChanged: (v) => v == null ? null : s.setDefaultPriority(v),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Low')),
                DropdownMenuItem(value: 1, child: Text('Normal')),
                DropdownMenuItem(value: 2, child: Text('High')),
              ],
            ),
          ),
          const _Header('Productivity & Platform Features'),
          const _FloatingPanelTile(),
          const _WidgetTile(),
          const _StartupTile(),
          _Cap('Universal clipboard (Milestone 5)', Capabilities.clipboardSync),
          const _Header('App updates'),
          const _UpdateTile(),
        ],
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
      leading: const Icon(Icons.picture_in_picture_alt),
      title: const Text('Floating task panel'),
      subtitle: const Text('Compact, always-on-top quick entry panel'),
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
      leading: const Icon(Icons.widgets_outlined),
      title: const Text('Home-screen widget'),
      subtitle: const Text('Android native widget with live pending tasks'),
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
      secondary: const Icon(Icons.rocket_launch_outlined),
      title: const Text('Launch at startup'),
      subtitle: const Text('Start SyncTask automatically in background'),
      value: _enabled,
      onChanged: (val) async {
        setState(() => _enabled = val);
        await _service.setLaunchAtStartup(val);
      },
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
  bool _checking = false;
  AppRelease? _release;
  String? _statusMessage;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _statusMessage = null;
    });

    final release = await _service.checkForUpdate();
    if (!mounted) return;

    setState(() {
      _checking = false;
      _release = release;
      if (release == null) {
        _statusMessage = 'App is up to date (v0.1.0)';
      }
    });
  }

  Future<void> _install() async {
    if (_release != null) {
      await _service.launchDownload(_release!.downloadUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Checking for updates...'),
      );
    }

    if (_release != null) {
      return ListTile(
        leading: const Icon(Icons.system_update, color: Colors.green),
        title: Text('Update available: ${_release!.versionTag}'),
        subtitle: Text(_release!.title),
        trailing: FilledButton.icon(
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Update'),
          onPressed: _install,
        ),
      );
    }

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset('assets/logo.png', width: 32, height: 32),
      ),
      title: const Text('SyncTask v0.1.0'),
      subtitle: Text(_statusMessage ?? 'Tap to check for new updates'),
      trailing: OutlinedButton(
        onPressed: _check,
        child: const Text('Check now'),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _Cap extends StatelessWidget {
  const _Cap(this.name, this.supported);
  final String name;
  final bool supported;
  @override
  Widget build(BuildContext context) => ListTile(
        enabled: false,
        title: Text(name),
        subtitle: Text(supported
            ? 'Supported on this OS (not implemented yet)'
            : 'Not supported on this OS'),
      );
}
