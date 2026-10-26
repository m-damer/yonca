import 'package:flutter/material.dart';

/// App-wide choices (language, theme). Persisted storage comes with the database milestone.
class AppController extends ChangeNotifier {
  AppController({Locale? locale, ThemeMode? themeMode})
      : _locale = locale ?? const Locale('en'),
        _themeMode = themeMode ?? ThemeMode.system;

  Locale _locale;
  ThemeMode _themeMode;

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;

  void setLocale(Locale value) {
    if (value == _locale) return;
    _locale = value;
    notifyListeners();
  }

  void setThemeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    notifyListeners();
  }
}
