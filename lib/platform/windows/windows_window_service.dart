import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppWindowMode {
  normal,
  bubble,
  panel,
}

/// Windows native window controller managing HWND styles, borderless regions,
/// window dragging, and "normal" / "bubble" / "panel" modes.
class WindowsWindowService {
  static const MethodChannel _channel = MethodChannel('com.synctask/window');

  static final ValueNotifier<AppWindowMode> currentMode =
      ValueNotifier<AppWindowMode>(AppWindowMode.normal);

  static bool get isSupported => Platform.isWindows;

  static void init() {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWindowModeChanged') {
        final args = call.arguments;
        String? modeStr;
        if (args is Map) {
          modeStr = args['mode']?.toString();
        } else if (args is String) {
          modeStr = args;
        }
        if (modeStr != null) {
          final mode = AppWindowMode.values.firstWhere(
            (m) => m.name == modeStr,
            orElse: () => AppWindowMode.normal,
          );
          currentMode.value = mode;
        }
      }
    });
  }

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
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('setWindowMode', {'mode': mode.name});
      currentMode.value = mode;
    } catch (_) {}
  }

  static Future<AppWindowMode> getWindowMode() async {
    if (!isSupported) return AppWindowMode.normal;
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

  static Future<void> setCloseToBubble(bool enabled) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('setCloseToBubble', {'enabled': enabled});
    } catch (_) {}
  }

  static Future<void> exitApp() async {
    if (!isSupported) {
      exit(0);
    }
    try {
      await _channel.invokeMethod('exitApp');
    } catch (_) {
      exit(0);
    }
  }
}

/// Backward compatibility alias
typedef PlatformWindowService = WindowsWindowService;
