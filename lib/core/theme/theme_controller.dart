import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../database/db_constants.dart';

/// Holds the app-wide [ThemeMode] and persists changes to the
/// `app_settings` table. Exposed as a [ValueNotifier] so `MaterialApp`
/// can rebuild via [ValueListenableBuilder].
class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  final _db = DatabaseHelper.instance;

  /// Reads the saved preference on startup. Defaults to system.
  Future<void> load() async {
    try {
      final saved = await _db.getSetting(DBConstants.keyThemeMode);
      mode.value = _fromString(saved);
    } catch (e) {
      debugPrint('⚠️ THEME: could not load preference: $e');
      mode.value = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode value) async {
    mode.value = value;
    try {
      await _db.setSetting(DBConstants.keyThemeMode, _toString(value));
    } catch (e) {
      debugPrint('⚠️ THEME: could not save preference: $e');
    }
  }

  /// Cycles light → dark → system, returning the new mode.
  Future<ThemeMode> toggle() async {
    final next = switch (mode.value) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    await setMode(next);
    return next;
  }

  static ThemeMode _fromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
