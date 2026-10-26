import 'dart:io';
import '../../platform/floating_panel_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../platform/startup_service.dart';
import '../../platform/window_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController._(this._prefs);
  final SharedPreferences _prefs;

  static const List<Color> themePalette = [
    Color(0xFF6366F1), // Electric Indigo
    Color(0xFF0284C7), // Deep Ocean Blue
    Color(0xFF06B6D4), // Cyber Cyan
    Color(0xFF10B981), // Emerald Mint
    Color(0xFF84CC16), // Lime Green
    Color(0xFFF59E0B), // Radiant Amber
    Color(0xFFF97316), // Sunset Coral
    Color(0xFF8B5CF6), // Royal Violet
    Color(0xFFEC4899), // Neon Pink
    Color(0xFF64748B), // Slate Titanium
  ];

  static const List<String> themeColorNames = [
    'Electric Indigo',
    'Ocean Blue',
    'Cyber Cyan',
    'Emerald Mint',
    'Lime Green',
    'Radiant Amber',
    'Sunset Coral',
    'Royal Violet',
    'Neon Pink',
    'Slate Titanium',
  ];

  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final controller = SettingsController._(prefs);
    if (controller.isAlwaysOnTop) {
      PlatformWindowService.setAlwaysOnTop(true);
    }
    if (Platform.isAndroid && controller.isFloatingBubbleEnabled) {
      PlatformFloatingPanelService().show();
    }
    return controller;
  }

  ThemeMode get themeMode =>
      ThemeMode.values.byName(_prefs.getString('themeMode') ?? 'system');

  bool get showCompleted => _prefs.getBool('showCompleted') ?? true;
  int get defaultPriority => _prefs.getInt('defaultPriority') ?? 1;

  int get themeColorIndex => _prefs.getInt('themeColorIndex') ?? 0;
  Color get themeSeedColor => themePalette[themeColorIndex % themePalette.length];

  bool get isAmoledDark => _prefs.getBool('isAmoledDark') ?? false;
  bool get isFloatingBubbleEnabled =>
      _prefs.getBool('isFloatingBubbleEnabled') ?? true;

  bool get isAlwaysOnTop => _prefs.getBool('isAlwaysOnTop') ?? false;
  bool get isLaunchAtStartup => _prefs.getBool('pref_launch_at_startup') ?? false;
  bool get isStartInBubbleMode => _prefs.getBool('isStartInBubbleMode') ?? false;

  Future<void> setThemeMode(ThemeMode m) async {
    await _prefs.setString('themeMode', m.name);
    notifyListeners();
  }

  Future<void> setShowCompleted(bool v) async {
    await _prefs.setBool('showCompleted', v);
    notifyListeners();
  }

  Future<void> setDefaultPriority(int v) async {
    await _prefs.setInt('defaultPriority', v);
    notifyListeners();
  }

  Future<void> setThemeColorIndex(int index) async {
    await _prefs.setInt('themeColorIndex', index);
    notifyListeners();
  }

  Future<void> setAmoledDark(bool enabled) async {
    await _prefs.setBool('isAmoledDark', enabled);
    notifyListeners();
  }

  Future<void> setFloatingBubbleEnabled(bool enabled) async {
    await _prefs.setBool('isFloatingBubbleEnabled', enabled);
    if (Platform.isAndroid) {
      if (enabled) {
        await PlatformFloatingPanelService().show();
      } else {
        await PlatformFloatingPanelService().hide();
      }
    }
    notifyListeners();
  }

  Future<void> setAlwaysOnTop(bool enabled) async {
    await _prefs.setBool('isAlwaysOnTop', enabled);
    await PlatformWindowService.setAlwaysOnTop(enabled);
    notifyListeners();
  }

  Future<void> setLaunchAtStartup(bool enabled) async {
    await _prefs.setBool('pref_launch_at_startup', enabled);
    await PlatformStartupService().setLaunchAtStartup(
      enabled,
      bubbleMode: isStartInBubbleMode,
    );
    notifyListeners();
  }

  Future<void> setStartInBubbleMode(bool enabled) async {
    await _prefs.setBool('isStartInBubbleMode', enabled);
    if (isLaunchAtStartup) {
      await PlatformStartupService().setLaunchAtStartup(
        true,
        bubbleMode: enabled,
      );
    }
    notifyListeners();
  }
}
