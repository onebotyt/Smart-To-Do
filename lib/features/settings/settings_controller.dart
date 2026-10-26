import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  SettingsController._(this._prefs);
  final SharedPreferences _prefs;

  static Future<SettingsController> load() async =>
      SettingsController._(await SharedPreferences.getInstance());

  ThemeMode get themeMode =>
      ThemeMode.values.byName(_prefs.getString('themeMode') ?? 'system');
  bool get showCompleted => _prefs.getBool('showCompleted') ?? true;
  int get defaultPriority => _prefs.getInt('defaultPriority') ?? 1;

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
}
