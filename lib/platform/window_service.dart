import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppWindowMode {
  normal,
  bubble,
  panel,
}

class PlatformWindowService {
  static const MethodChannel _channel = MethodChannel('com.synctask/window');

  static final ValueNotifier<AppWindowMode> currentMode =
      ValueNotifier<AppWindowMode>(AppWindowMode.normal);

  static bool get isSupported => Platform.isWindows;

  static Future<bool> setAlwaysOnTop(bool alwaysOnTop) async {
    if (!isSupported) return false;
    try {
      final res = await _channel.invokeMethod<bool>(
        'setAlwaysOnTop',
        {'alwaysOnTop': alwaysOnTop},
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isAlwaysOnTop() async {
    if (!isSupported) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isAlwaysOnTop');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setWindowMode(AppWindowMode mode) async {
    currentMode.value = mode;
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('setWindowMode', {'mode': mode.name});
    } catch (_) {}
  }

  static Future<AppWindowMode> getWindowMode() async {
    if (!isSupported) return currentMode.value;
    try {
      final res = await _channel.invokeMethod<String>('getWindowMode');
      if (res != null) {
        final mode = AppWindowMode.values.firstWhere(
          (m) => m.name == res,
          orElse: () => AppWindowMode.normal,
        );
        currentMode.value = mode;
        return mode;
      }
    } catch (_) {}
    return currentMode.value;
  }

  static Future<void> moveWindow(double dx, double dy) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('moveWindow', {'dx': dx, 'dy': dy});
    } catch (_) {}
  }

  static Future<void> startDragging() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('startDragging');
    } catch (_) {}
  }
}
