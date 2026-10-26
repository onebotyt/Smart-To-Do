import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/capabilities.dart';
import '../../platform/update_service.dart';
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
          const _Header('Platform features'),
          _Cap('Floating panel', Capabilities.floatingPanel),
          _Cap('Home-screen widgets', Capabilities.homeWidgets),
          _Cap('Clipboard sharing', Capabilities.clipboardSync),
          _Cap('Launch at startup', Capabilities.launchAtStartup),
          const _Header('App updates'),
          const _UpdateTile(),
        ],
      ),
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
