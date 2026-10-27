import 'dart:io';
import 'package:flutter/services.dart';
import 'package:synctask/core/logger/app_logger.dart';

/// Windows native Win32 hardware & settings controller.
/// Dispatches directly to Win32 ShellExecuteW ms-settings without CMD prompt.
class WindowsSettingsService {
  static const MethodChannel _channel = MethodChannel('com.synctask/native_settings');

  static bool get isSupported => Platform.isWindows;

  static Future<bool> openBluetoothSettings() async {
    if (!isSupported) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>('openBluetoothSettings');
      return ok ?? false;
    } catch (e) {
      AppLogger.error('settings', 'Failed to open Windows Bluetooth settings', e);
      return false;
    }
  }

  static Future<bool> openWifiSettings() async {
    if (!isSupported) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>('openWifiSettings');
      return ok ?? false;
    } catch (e) {
      AppLogger.error('settings', 'Failed to open Windows Wi-Fi settings', e);
      return false;
    }
  }

  static Future<bool> openHotspotSettings() async {
    if (!isSupported) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>('openHotspotSettings');
      return ok ?? false;
    } catch (e) {
      AppLogger.error('settings', 'Failed to open Windows Hotspot settings', e);
      return false;
    }
  }
}
