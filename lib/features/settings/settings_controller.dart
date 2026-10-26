import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  SettingsController._(this._prefs);
  final SharedPreferences _prefs;

  static const List<Color> themePalette = [
    Color(0xFF4F46E5), // Indigo (Classic)
    Color(0xFF0284C7), // Ocean Blue
    Color(0xFF0D9488), // Teal
    Color(0xFF059669), // Emerald Green
    Color(0xFFD97706), // Sunset Amber
    Color(0xFF7C3AED), // Royal Purple
    Color(0xFFE11D48), // Rose
    Color(0xFF475569), // Slate
  ];

  static const List<String> themeColorNames = [
    'Indigo',
    'Ocean Blue',
    'Teal',
    'Emerald Green',
    'Sunset Amber',
    'Royal Purple',
    'Rose',
    'Slate',
  ];

  static Future<SettingsController> load() async =>
      SettingsController._(await SharedPreferences.getInstance());

  ThemeMode get themeMode =>
      ThemeMode.values.byName(_prefs.getString('themeMode') ?? 'system');

  bool get showCompleted => _prefs.getBool('showCompleted') ?? true;
  int get defaultPriority => _prefs.getInt('defaultPriority') ?? 1;

  int get themeColorIndex => _prefs.getInt('themeColorIndex') ?? 0;
  Color get themeSeedColor => themePalette[themeColorIndex % themePalette.length];

  bool get isAmoledDark => _prefs.getBool('isAmoledDark') ?? false;
  bool get isFloatingBubbleEnabled =>
      _prefs.getBool('isFloatingBubbleEnabled') ?? true;

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
    notifyListeners();
  }
}
