import 'dart:io';
import 'package:flutter/services.dart';

abstract class WidgetService {
  bool get isSupported;
  Future<void> updateWidget({
    required int pendingCount,
    required List<String> topTaskTitles,
  });
}

class PlatformWidgetService implements WidgetService {
  static const MethodChannel _channel = MethodChannel('com.synctask/widget');

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Future<void> updateWidget({
    required int pendingCount,
    required List<String> topTaskTitles,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('updateWidget', {
        'pendingCount': pendingCount,
        'topTasks': topTaskTitles.take(5).toList(),
      });
    } catch (_) {}
  }
}
