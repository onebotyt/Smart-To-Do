import 'dart:io';
import 'package:flutter/services.dart';

/// Platform-specific media sharing & clipboard image service.
/// Uses native Android FileProvider + Intent.ACTION_SEND for system app chooser,
/// and native Windows shell integration on desktop.
class NativeMediaService {
  static const MethodChannel _channel = MethodChannel('com.synctask/media_share');

  /// Shares a file using the native system share sheet (e.g. Android app chooser).
  static Future<bool> shareFile({
    required String filePath,
    String? mimeType,
  }) async {
    if (Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('shareFile', {
          'filePath': filePath,
          'mimeType': mimeType ?? _guessMimeType(filePath),
        });
        return res ?? false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Checks if an image / screenshot is currently on the system clipboard
  /// and returns its local cached file path, or null if none.
  static Future<String?> getClipboardImage() async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod<String>('getClipboardImage');
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Sends a system notification on desktop (Windows) when media is received.
  static Future<void> notifyMediaReceived({
    required String title,
    required String message,
  }) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    if (Platform.isWindows) {
      try {
        // Native Windows Action Center toast via PowerShell (hidden window)
        final escapedTitle = title.replaceAll("'", "''");
        final escapedMsg = message.replaceAll("'", "''");
        final script = '''
\$template = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02);
\$nodes = \$template.GetElementsByTagName('text');
\$nodes.Item(0).InnerText = '$escapedTitle';
\$nodes.Item(1).InnerText = '$escapedMsg';
\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$template);
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('SyncTask').Show(\$toast);
''';
        await Process.run('powershell', ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', script]);
      } catch (_) {}
    }
  }

  static String _guessMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mkv':
        return 'video/x-matroska';
      case 'pdf':
        return 'application/pdf';
      case 'zip':
        return 'application/zip';
      case 'txt':
        return 'text/plain';
      default:
        return '*/*';
    }
  }
}
