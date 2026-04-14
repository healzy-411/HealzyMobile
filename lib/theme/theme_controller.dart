import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global dark/light mode controller. Persists via SharedPreferences.
class ThemeController extends ChangeNotifier {
  static final ThemeController I = ThemeController._();
  ThemeController._();

  static const _prefKey = 'healzy_theme_mode';

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'dark') {
        _mode = ThemeMode.dark;
      } else if (saved == 'light') {
        _mode = ThemeMode.light;
      }
      notifyListeners();
    } catch (_) {
      // fallback to default
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        mode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {}
  }

  Future<void> toggle() async {
    await setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
