import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;
  final Map<String, dynamic>? data;
  final String? error;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.data,
    this.error,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String get levelTag => level.name.toUpperCase();

  @override
  String toString() {
    final dataStr = data != null && data!.isNotEmpty ? ' | data: ${jsonEncode(data)}' : '';
    final errStr = error != null ? ' | error: $error' : '';
    return '[$formattedTime][$levelTag][$category] $message$dataStr$errStr';
  }
}

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  static const int maxMemoryLogs = 600;
  final List<LogEntry> _logs = [];
  final StreamController<LogEntry> _streamController = StreamController<LogEntry>.broadcast();

  File? _logFile;
  bool _initialized = false;

  List<LogEntry> get logs => List.unmodifiable(_logs);
  Stream<LogEntry> get logStream => _streamController.stream;

  static Future<void> init() async {
    await _instance._initFile();
  }

  Future<void> _initFile() async {
    if (_initialized) return;
    try {
      Directory? dir;
      try {
        dir = await getApplicationSupportDirectory();
      } catch (_) {}
      dir ??= Directory.systemTemp;

      final logDir = Directory(path.join(dir.path, 'SyncTaskLogs'));
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      _logFile = File(path.join(logDir.path, 'synctask_actions.log'));

      // If log file is too big (>2 MB), rotate it
      if (_logFile!.existsSync() && _logFile!.lengthSync() > 2 * 1024 * 1024) {
        final backup = File(path.join(logDir.path, 'synctask_actions.old.log'));
        if (backup.existsSync()) backup.deleteSync();
        _logFile!.renameSync(backup.path);
        _logFile = File(path.join(logDir.path, 'synctask_actions.log'));
      }

      _initialized = true;
      info('system', 'AppLogger initialized. OS: ${Platform.operatingSystem}');
    } catch (e) {
      debugPrint('[AppLogger] Init failed: $e');
    }
  }

  static void debug(String category, String message, [Map<String, dynamic>? data]) {
    _instance._log(LogLevel.debug, category, message, data: data);
  }

  static void info(String category, String message, [Map<String, dynamic>? data]) {
    _instance._log(LogLevel.info, category, message, data: data);
  }

  static void warning(String category, String message, [Map<String, dynamic>? data]) {
    _instance._log(LogLevel.warning, category, message, data: data);
  }

  static void error(String category, String message, [Object? error, StackTrace? stack]) {
    final errStr = error != null ? (stack != null ? '$error\n$stack' : error.toString()) : null;
    _instance._log(LogLevel.error, category, message, error: errStr);
  }

  void _log(
    LogLevel level,
    String category,
    String message, {
    Map<String, dynamic>? data,
    String? error,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      data: data,
      error: error,
    );

    if (_logs.length >= maxMemoryLogs) {
      _logs.removeAt(0);
    }
    _logs.add(entry);

    if (!_streamController.isClosed) {
      _streamController.add(entry);
    }

    debugPrint(entry.toString());

    // Asynchronously write to file
    _writeToFile(entry.toString());
  }

  void _writeToFile(String line) {
    if (_logFile == null) return;
    try {
      _logFile!.writeAsStringSync('$line\n', mode: FileMode.append, flush: false);
    } catch (_) {}
  }

  void clear() {
    _logs.clear();
    try {
      if (_logFile != null && _logFile!.existsSync()) {
        _logFile!.writeAsStringSync('');
      }
    } catch (_) {}
  }

  String generateMarkdownReport({
    String? deviceId,
    String? deviceName,
    List<String>? detectedIps,
    int? pairedDevicesCount,
  }) {
    final buffer = StringBuffer();
    final now = DateTime.now().toUtc().toIso8601String();

    buffer.writeln('### SyncTask Diagnostic & Action Report');
    buffer.writeln('- **Timestamp**: `$now UTC`');
    buffer.writeln('- **Platform**: `${Platform.operatingSystem} (${Platform.operatingSystemVersion})`');
    buffer.writeln('- **Device Name**: `${deviceName ?? "Unknown"}`');
    buffer.writeln('- **Device ID**: `${deviceId ?? "Unknown"}`');
    if (detectedIps != null && detectedIps.isNotEmpty) {
      buffer.writeln('- **Detected IPs**: `${detectedIps.join(", ")}`');
    }
    if (pairedDevicesCount != null) {
      buffer.writeln('- **Paired Devices Count**: `$pairedDevicesCount`');
    }
    buffer.writeln();
    buffer.writeln('#### Action Log (${_logs.length} entries)');
    buffer.writeln('```log');
    for (final l in _logs) {
      buffer.writeln(l.toString());
    }
    buffer.writeln('```');

    return buffer.toString();
  }
}

class GitHubLogService {
  static const String repoOwner = 'onebotyt';
  static const String repoName = 'Smart-To-Do';

  /// Prepares report and opens GitHub Issue creator in browser with all logs pre-filled.
  static Future<bool> sendLogsToGitHub({
    String? deviceId,
    String? deviceName,
    List<String>? detectedIps,
    int? pairedDevicesCount,
  }) async {
    final report = AppLogger().generateMarkdownReport(
      deviceId: deviceId,
      deviceName: deviceName,
      detectedIps: detectedIps,
      pairedDevicesCount: pairedDevicesCount,
    );

    // Also copy to clipboard so user has it immediately
    try {
      await Clipboard.setData(ClipboardData(text: report));
    } catch (_) {}

    final title = Uri.encodeComponent(
      '[Bug/Log] ${Platform.operatingSystem} - ${deviceName ?? "Device"} (${DateTime.now().toIso8601String().substring(0, 16)})',
    );

    // If report is short enough (<3500 chars), put directly in URL query param
    String bodyParam;
    if (report.length < 3500) {
      bodyParam = Uri.encodeComponent(report);
    } else {
      // Put recent 40 lines and indicate clipboard has full log
      final recentLogs = AppLogger().logs.reversed.take(40).toList().reversed;
      final preview = StringBuffer();
      preview.writeln('### Diagnostic Summary (Full log copied to clipboard!)');
      preview.writeln('- Platform: ${Platform.operatingSystem}');
      preview.writeln('- Device: ${deviceName ?? "Unknown"} ($deviceId)');
      preview.writeln();
      preview.writeln('#### Recent Action Log Tail');
      preview.writeln('```log');
      for (final l in recentLogs) {
        preview.writeln(l.toString());
      }
      preview.writeln('```');
      preview.writeln('\n*(Note: The complete diagnostic report has also been copied to your clipboard. You can paste it below)*');
      bodyParam = Uri.encodeComponent(preview.toString());
    }

    final url = Uri.parse(
      'https://github.com/$repoOwner/$repoName/issues/new?title=$title&body=$bodyParam&labels=bug,diagnostics',
    );

    AppLogger.info('github', 'Opening GitHub Issue with diagnostic logs: $url');

    try {
      if (await canLaunchUrl(url)) {
        return await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.error('github', 'Failed to launch GitHub issue URL', e);
    }

    // Fallback: open base repo issues URL
    final fallbackUrl = Uri.parse('https://github.com/$repoOwner/$repoName/issues/new');
    return await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
  }
}
