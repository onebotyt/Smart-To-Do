import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Windows native startup autorun service.
/// Sets or removes `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\SyncTask`.
class WindowsStartupService {
  static const MethodChannel _channel = MethodChannel('com.synctask/startup');
  static const String _prefKey = 'pref_launch_at_startup';

  static bool get isSupported => Platform.isWindows;

  static Future<bool> isLaunchAtStartupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final prefValue = prefs.getBool(_prefKey) ?? false;

    if (!isSupported) return prefValue;

    try {
      final res = await _channel.invokeMethod<bool>('isEnabled');
      return res ?? prefValue;
    } catch (_) {
      return prefValue;
    }
  }

  static Future<void> setLaunchAtStartup(bool enabled, {bool bubbleMode = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);

    if (!isSupported) return;

    try {
      await _channel.invokeMethod('setEnabled', {
        'enabled': enabled,
        'bubbleMode': bubbleMode,
      });
    } catch (_) {}
  }
}
