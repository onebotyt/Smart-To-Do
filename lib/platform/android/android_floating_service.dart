import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Android-specific overlay bubble service.
/// Uses SYSTEM_ALERT_WINDOW and Android FloatingBubbleService via MethodChannel('com.synctask/floating_panel').
class AndroidFloatingService {
  static const MethodChannel _channel = MethodChannel('com.synctask/floating_panel');

  final StreamController<bool> _visibilityController =
      StreamController<bool>.broadcast();
  bool _localVisible = false;

  AndroidFloatingService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onVisibilityChanged') {
        final visible = call.arguments as bool? ?? false;
        _localVisible = visible;
        _visibilityController.add(visible);
      }
    });
  }

  bool get isSupported => Platform.isAndroid;
  Stream<bool> get onVisibilityChanged => _visibilityController.stream;

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      final res = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestPermission() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  Future<void> openAppSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  Future<bool> isVisible() async {
    if (!isSupported) return _localVisible;
    try {
      final res = await _channel.invokeMethod<bool>('isVisible');
      return res ?? _localVisible;
    } catch (_) {
      return _localVisible;
    }
  }

  Future<void> show() async {
    _localVisible = true;
    _visibilityController.add(true);
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('show');
    } catch (_) {}
  }

  Future<void> hide() async {
    _localVisible = false;
    _visibilityController.add(false);
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('hide');
    } catch (_) {}
  }

  Future<void> toggle() async {
    final current = await isVisible();
    if (current) {
      await hide();
    } else {
      await show();
    }
  }
}
