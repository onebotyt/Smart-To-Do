import 'dart:io';
import 'package:flutter/services.dart';

abstract class TrayService {
  bool get isSupported;
  Future<void> initTray({
    required VoidCallback onToggle,
    required VoidCallback onExit,
    required VoidCallback onSync,
  });
  Future<void> setTooltip(String tooltip);
  Future<void> dispose();
}

class PlatformTrayService implements TrayService {
  static const MethodChannel _channel = MethodChannel('com.synctask/tray');

  VoidCallback? _onToggle;
  VoidCallback? _onExit;
  VoidCallback? _onSync;

  PlatformTrayService() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onToggle':
          _onToggle?.call();
          break;
        case 'onExit':
          _onExit?.call();
          break;
        case 'onSync':
          _onSync?.call();
          break;
      }
    });
  }

  @override
  bool get isSupported => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Future<void> initTray({
    required VoidCallback onToggle,
    required VoidCallback onExit,
    required VoidCallback onSync,
  }) async {
    _onToggle = onToggle;
    _onExit = onExit;
    _onSync = onSync;

    if (!isSupported) return;
    try {
      await _channel.invokeMethod('initTray');
    } catch (_) {}
  }

  @override
  Future<void> setTooltip(String tooltip) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('setTooltip', {'tooltip': tooltip});
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('dispose');
    } catch (_) {}
  }
}
