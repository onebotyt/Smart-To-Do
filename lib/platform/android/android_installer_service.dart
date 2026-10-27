import 'dart:io';
import 'package:flutter/services.dart';

/// Android native APK installer service.
/// Invokes Android PackageInstaller / FileProvider via MethodChannel('com.synctask/installer').
class AndroidInstallerService {
  static const MethodChannel _channel = MethodChannel('com.synctask/installer');

  static bool get isSupported => Platform.isAndroid;

  static Future<bool> installApk(String filePath) async {
    if (!isSupported) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
