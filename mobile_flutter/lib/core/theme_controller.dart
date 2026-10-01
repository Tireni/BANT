import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BantThemePreference { system, light, dark }

class BantThemeController extends ChangeNotifier {
  static const _key = 'bant-theme-preference';
  BantThemePreference preference = BantThemePreference.system;

  ThemeMode get mode {
    switch (preference) {
      case BantThemePreference.light:
        return ThemeMode.light;
      case BantThemePreference.dark:
        return ThemeMode.dark;
      case BantThemePreference.system:
        return ThemeMode.system;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    preference = switch (value) {
      'light' => BantThemePreference.light,
      'dark' => BantThemePreference.dark,
      _ => BantThemePreference.system,
    };
    notifyListeners();
  }

  Future<void> setPreference(BantThemePreference value) async {
    preference = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
  }
}
