import 'dart:io';

import 'package:flutter/services.dart';
import 'package:synctask/core/logger/app_logger.dart';
import 'package:url_launcher/url_launcher.dart';

class NativeNetworkService {
  static const MethodChannel _channel = MethodChannel('com.synctask/native_settings');

  /// Check if Bluetooth is currently enabled on Android (returns null or true on desktop).
  static Future<bool> isBluetoothEnabled() async {
    if (Platform.isAndroid) {
      try {
        final bool? enabled = await _channel.invokeMethod<bool>('isBluetoothEnabled');
        AppLogger.debug('network', 'Android isBluetoothEnabled: $enabled');
        return enabled ?? false;
      } catch (e) {
        AppLogger.error('network', 'Error checking Bluetooth status', e);
        return false;
      }
    }
    // On Windows/Linux/macOS, return true as assumption
    return true;
  }

  /// Open native system Bluetooth settings.
  static Future<bool> openBluetoothSettings() async {
    AppLogger.info('network', 'Opening native Bluetooth settings on ${Platform.operatingSystem}');
    if (Platform.isAndroid) {
      try {
        final bool? ok = await _channel.invokeMethod<bool>('openBluetoothSettings');
        return ok ?? false;
      } catch (e) {
        AppLogger.error('network', 'Failed to open Android Bluetooth settings', e);
        return false;
      }
    } else if (Platform.isWindows) {
      return await _launchWindowsUri('ms-settings:bluetooth');
    }
    return false;
  }

  /// Open native system Wi-Fi settings.
  static Future<bool> openWifiSettings() async {
    AppLogger.info('network', 'Opening native Wi-Fi settings on ${Platform.operatingSystem}');
    if (Platform.isAndroid) {
      try {
        final bool? ok = await _channel.invokeMethod<bool>('openWifiSettings');
        return ok ?? false;
      } catch (e) {
        AppLogger.error('network', 'Failed to open Android Wi-Fi settings', e);
        return false;
      }
    } else if (Platform.isWindows) {
      return await _launchWindowsUri('ms-settings:network-wifi');
    }
    return false;
  }

  /// Open native system Hotspot / Tethering settings.
  static Future<bool> openHotspotSettings() async {
    AppLogger.info('network', 'Opening native Hotspot settings on ${Platform.operatingSystem}');
    if (Platform.isAndroid) {
      try {
        final bool? ok = await _channel.invokeMethod<bool>('openHotspotSettings');
        return ok ?? false;
      } catch (e) {
        AppLogger.error('network', 'Failed to open Android Hotspot settings', e);
        return false;
      }
    } else if (Platform.isWindows) {
      return await _launchWindowsUri('ms-settings:network-mobilehotspot');
    }
    return false;
  }

  static Future<bool> _launchWindowsUri(String uriString) async {
    try {
      final uri = Uri.parse(uriString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      Process.run('cmd', ['/c', 'start', uriString]);
      return true;
    } catch (e) {
      AppLogger.error('network', 'Failed to launch Windows settings URI: $uriString', e);
      try {
        Process.run('cmd', ['/c', 'start', uriString]);
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}
