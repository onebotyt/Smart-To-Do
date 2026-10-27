import 'dart:io';
import 'package:flutter/services.dart';
import 'package:synctask/core/logger/app_logger.dart';

/// Windows native update installer.
/// Executes Inno Setup silently using Win32 ShellExecuteExW with SW_HIDE
/// or portable ZIP extraction via CreateProcessW, with ZERO cmd.exe console popups.
class WindowsNativeUpdateService {
  static const MethodChannel _channel = MethodChannel('com.synctask/native_update');

  static bool get isSupported => Platform.isWindows;

  /// Trigger official native Win32 update installation and cleanly exit current process.
  static Future<bool> installUpdate({
    required String installerPath,
    required bool isZip,
  }) async {
    if (!isSupported) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>('installUpdate', {
        'installerPath': installerPath,
        'isZip': isZip,
      });
      return ok ?? false;
    } catch (e) {
      AppLogger.error('update', 'Native Win32 update failed', e);
      return false;
    }
  }
}
