import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/capabilities.dart';
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
        ],
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
