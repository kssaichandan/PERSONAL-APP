import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/snackbar_utils.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _colorSeed = Colors.deepPurple;
  bool _notificationsEnabled = true;
  bool _habitRemindersEnabled = true;
  bool _eventRemindersEnabled = true;
  bool _scientificMode = false;
  bool _copyOnTap = true;
  bool _weekStartsMonday = true;
  bool _loading = true;

  ThemeMode get themeMode => _themeMode;
  Color get colorSeed => _colorSeed;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get habitRemindersEnabled => _habitRemindersEnabled;
  bool get eventRemindersEnabled => _eventRemindersEnabled;
  bool get scientificMode => _scientificMode;
  bool get copyOnTap => _copyOnTap;
  bool get weekStartsMonday => _weekStartsMonday;
  bool get loading => _loading;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _loading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      _themeMode = ThemeMode.values.byName(
        prefs.getString('theme_mode') ?? 'system',
      );
      final colorSeedValue =
          prefs.getInt('color_seed') ?? Colors.deepPurple.toARGB32();
      _colorSeed = Color(colorSeedValue);
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _habitRemindersEnabled = prefs.getBool('habit_reminders_enabled') ?? true;
      _eventRemindersEnabled = prefs.getBool('event_reminders_enabled') ?? true;
      _scientificMode = prefs.getBool('calculator_scientific_mode') ?? false;
      _copyOnTap = prefs.getBool('calculator_copy_on_tap') ?? true;
      _weekStartsMonday = prefs.getBool('week_starts_monday') ?? true;
    } catch (e) {
      debugLog('Failed to load settings: $e');
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode.name);
    } catch (e) {
      debugLog('Failed to save theme mode: $e');
    }
  }

  Future<void> setColorSeed(Color color) async {
    _colorSeed = color;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('color_seed', color.toARGB32());
    } catch (e) {
      debugLog('Failed to save color seed: $e');
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', enabled);
    } catch (e) {
      debugLog('Failed to save notifications setting: $e');
    }
  }

  Future<void> setHabitRemindersEnabled(bool enabled) async {
    _habitRemindersEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('habit_reminders_enabled', enabled);
    } catch (e) {
      debugLog('Failed to save habit reminders setting: $e');
    }
  }

  Future<void> setEventRemindersEnabled(bool enabled) async {
    _eventRemindersEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('event_reminders_enabled', enabled);
    } catch (e) {
      debugLog('Failed to save event reminders setting: $e');
    }
  }

  Future<void> setScientificMode(bool enabled) async {
    _scientificMode = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('calculator_scientific_mode', enabled);
    } catch (e) {
      debugLog('Failed to save scientific mode: $e');
    }
  }

  Future<void> setCopyOnTap(bool enabled) async {
    _copyOnTap = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('calculator_copy_on_tap', enabled);
    } catch (e) {
      debugLog('Failed to save copy on tap setting: $e');
    }
  }

  Future<void> setWeekStartsMonday(bool value) async {
    _weekStartsMonday = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('week_starts_monday', value);
    } catch (e) {
      debugLog('Failed to save week start setting: $e');
    }
  }

  Future<void> reload() async {
    await _loadSettings();
  }

  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.system;
    _colorSeed = Colors.deepPurple;
    _notificationsEnabled = true;
    _habitRemindersEnabled = true;
    _eventRemindersEnabled = true;
    _scientificMode = false;
    _copyOnTap = true;
    _weekStartsMonday = true;
    _loading = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('theme_mode');
      await prefs.remove('color_seed');
      await prefs.remove('notifications_enabled');
      await prefs.remove('habit_reminders_enabled');
      await prefs.remove('event_reminders_enabled');
      await prefs.remove('calculator_scientific_mode');
      await prefs.remove('calculator_copy_on_tap');
      await prefs.remove('week_starts_monday');
    } catch (e) {
      debugLog('Failed to reset settings: $e');
    }
  }
}
