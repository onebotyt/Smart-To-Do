import 'dart:io';
import 'package:flutter/services.dart';

class PlatformWindowService {
  static const MethodChannel _channel = MethodChannel('com.synctask/window');

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
}
