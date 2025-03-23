import 'package:shared_preferences/shared_preferences.dart';

/// A service class to interact with SharedPreferences for persistent local storage
class SharedPrefs {
  static SharedPreferences? _prefs;

  /// Initialize the SharedPreferences instance
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Ensure onboarding is shown again for testing
    await setBool('hasCompletedOnboarding', false);
  }

  /// Get a boolean value from SharedPreferences
  static bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  /// Set a boolean value in SharedPreferences
  static Future<bool> setBool(String key, bool value) async {
    return await _prefs?.setBool(key, value) ?? false;
  }

  /// Get a string value from SharedPreferences
  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  /// Set a string value in SharedPreferences
  static Future<bool> setString(String key, String value) async {
    return await _prefs?.setString(key, value) ?? false;
  }

  /// Get an integer value from SharedPreferences
  static int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  /// Set an integer value in SharedPreferences
  static Future<bool> setInt(String key, int value) async {
    return await _prefs?.setInt(key, value) ?? false;
  }

  /// Get a double value from SharedPreferences
  static double? getDouble(String key) {
    return _prefs?.getDouble(key);
  }

  /// Set a double value in SharedPreferences
  static Future<bool> setDouble(String key, double value) async {
    return await _prefs?.setDouble(key, value) ?? false;
  }

  /// Get a list of strings from SharedPreferences
  static List<String>? getStringList(String key) {
    return _prefs?.getStringList(key);
  }

  /// Set a list of strings in SharedPreferences
  static Future<bool> setStringList(String key, List<String> value) async {
    return await _prefs?.setStringList(key, value) ?? false;
  }

  /// Remove a value from SharedPreferences
  static Future<bool> remove(String key) async {
    return await _prefs?.remove(key) ?? false;
  }

  /// Clear all values from SharedPreferences
  static Future<bool> clear() async {
    return await _prefs?.clear() ?? false;
  }

  /// Check if a key exists in SharedPreferences
  static bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }
}
