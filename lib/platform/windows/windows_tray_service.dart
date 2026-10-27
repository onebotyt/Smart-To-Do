import 'dart:io';
import 'package:flutter/services.dart';

/// Windows system notification tray integration.
class WindowsTrayService {
  static const MethodChannel _channel = MethodChannel('com.synctask/tray');

  VoidCallback? _onToggle;
  VoidCallback? _onExit;
  VoidCallback? _onSync;

  WindowsTrayService() {
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

  bool get isSupported => Platform.isWindows;

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

  Future<void> setTooltip(String tooltip) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('setTooltip', {'tooltip': tooltip});
    } catch (_) {}
  }

  Future<void> dispose() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('destroyTray');
    } catch (_) {}
  }
}
