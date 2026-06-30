import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._();
  ThemeService._();
  factory ThemeService() => _instance;

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final isDark = sp.getBool('theme_dark') ?? true;
    _mode = isDark ? ThemeMode.dark : ThemeMode.light;
    // No notifyListeners here — called before runApp
  }

  Future<void> setDark(bool dark) async {
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('theme_dark', dark);
  }
}
