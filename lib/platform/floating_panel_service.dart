import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

abstract class FloatingPanelService {
  bool get isSupported;
  Future<bool> hasPermission();
  Future<void> requestPermission();
  Future<bool> isVisible();
  Future<void> show();
  Future<void> hide();
  Future<void> toggle();
  Stream<bool> get onVisibilityChanged;
}

/// Default implementation communicating via MethodChannel when supported,
/// or providing in-app floating overlay state.
class PlatformFloatingPanelService implements FloatingPanelService {
  static const MethodChannel _channel = MethodChannel('com.synctask/floating_panel');

  final StreamController<bool> _visibilityController =
      StreamController<bool>.broadcast();
  bool _localVisible = false;

  PlatformFloatingPanelService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onVisibilityChanged') {
        final visible = call.arguments as bool? ?? false;
        _localVisible = visible;
        _visibilityController.add(visible);
      }
    });
  }

  @override
  bool get isSupported => Platform.isAndroid || Platform.isWindows;

  @override
  Stream<bool> get onVisibilityChanged => _visibilityController.stream;

  @override
  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    if (Platform.isWindows) return true; // Windows always allows floating windows
    try {
      final res = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> requestPermission() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  @override
  Future<bool> isVisible() async {
    if (!isSupported) return _localVisible;
    try {
      final res = await _channel.invokeMethod<bool>('isVisible');
      return res ?? _localVisible;
    } catch (_) {
      return _localVisible;
    }
  }

  @override
  Future<void> show() async {
    _localVisible = true;
    _visibilityController.add(true);
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('show');
    } catch (_) {}
  }

  @override
  Future<void> hide() async {
    _localVisible = false;
    _visibilityController.add(false);
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('hide');
    } catch (_) {}
  }

  @override
  Future<void> toggle() async {
    final current = await isVisible();
    if (current) {
      await hide();
    } else {
      await show();
    }
  }

  void dispose() {
    _visibilityController.close();
  }
}
