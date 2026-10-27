import 'dart:io';

import 'package:flutter/services.dart';
import 'package:synctask/core/logger/app_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cross-platform service for accessing native OS hardware & network settings
/// (Bluetooth, Wi-Fi, Mobile Hotspot) without spawning console/cmd prompts.
class NativeNetworkService {
  static const MethodChannel _channel = MethodChannel('com.synctask/native_settings');

  /// Check if Bluetooth is currently enabled on the device.
  static Future<bool> isBluetoothEnabled() async {
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('isBluetoothEnabled');
      AppLogger.debug('network', 'isBluetoothEnabled: $enabled');
      return enabled ?? false;
    } catch (e) {
      AppLogger.error('network', 'Error checking Bluetooth status', e);
      return false;
    }
  }

  /// Open native system Bluetooth settings.
  static Future<bool> openBluetoothSettings() async {
    AppLogger.info('network', 'Opening native Bluetooth settings on ${Platform.operatingSystem}');
    try {
      final bool? ok = await _channel.invokeMethod<bool>('openBluetoothSettings');
      if (ok == true) return true;
    } catch (e) {
      AppLogger.error('network', 'Failed to open Bluetooth settings via channel', e);
    }
    // Fallback: direct OS URI launcher without cmd.exe
    return await _launchDirectUri('ms-settings:bluetooth');
  }

  /// Open native system Wi-Fi settings.
  static Future<bool> openWifiSettings() async {
    AppLogger.info('network', 'Opening native Wi-Fi settings on ${Platform.operatingSystem}');
    try {
      final bool? ok = await _channel.invokeMethod<bool>('openWifiSettings');
      if (ok == true) return true;
    } catch (e) {
      AppLogger.error('network', 'Failed to open Wi-Fi settings via channel', e);
    }
    return await _launchDirectUri('ms-settings:network-wifi');
  }

  /// Open native system Hotspot / Tethering settings.
  static Future<bool> openHotspotSettings() async {
    AppLogger.info('network', 'Opening native Hotspot settings on ${Platform.operatingSystem}');
    try {
      final bool? ok = await _channel.invokeMethod<bool>('openHotspotSettings');
      if (ok == true) return true;
    } catch (e) {
      AppLogger.error('network', 'Failed to open Hotspot settings via channel', e);
    }
    return await _launchDirectUri('ms-settings:network-mobilehotspot');
  }

  static Future<bool> _launchDirectUri(String uriString) async {
    try {
      final uri = Uri.parse(uriString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
