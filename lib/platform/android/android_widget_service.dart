import 'dart:io';
import 'package:flutter/services.dart';

/// Android Home Screen AppWidget service.
/// Communicates with Kotlin SyncTaskWidgetProvider via MethodChannel('com.synctask/widget').
class AndroidWidgetService {
  static const MethodChannel _channel = MethodChannel('com.synctask/widget');

  bool get isSupported => Platform.isAndroid;

  Future<void> updateWidget({
    required int pendingCount,
    required List<String> topTaskTitles,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('updateWidget', {
        'pendingCount': pendingCount,
        'topTasks': topTaskTitles.take(6).toList(),
      });
    } catch (_) {}
  }
}
