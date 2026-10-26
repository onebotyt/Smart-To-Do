import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class StartupService {
  bool get isSupported;
  Future<bool> isLaunchAtStartupEnabled();
  Future<void> setLaunchAtStartup(bool enabled);
}

class PlatformStartupService implements StartupService {
  static const MethodChannel _channel = MethodChannel('com.synctask/startup');
  static const String _prefKey = 'pref_launch_at_startup';

  @override
  bool get isSupported => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Future<bool> isLaunchAtStartupEnabled() async {
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

  @override
  Future<void> setLaunchAtStartup(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);

    if (!isSupported) return;

    try {
      await _channel.invokeMethod('setEnabled', {'enabled': enabled});
    } catch (_) {}
  }
}
