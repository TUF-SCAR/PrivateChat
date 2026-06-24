import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  LocalStore._();

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _instance() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<String?> getString(String key) async {
    final prefs = await _instance();
    return prefs.getString(key);
  }

  static Future<void> setString(String key, String value) async {
    final prefs = await _instance();
    await prefs.setString(key, value);
  }

  static Future<int?> getInt(String key) async {
    final prefs = await _instance();
    return prefs.getInt(key);
  }

  static Future<void> setInt(String key, int value) async {
    final prefs = await _instance();
    await prefs.setInt(key, value);
  }

  static Future<bool?> getBool(String key) async {
    final prefs = await _instance();
    return prefs.getBool(key);
  }

  static Future<void> setBool(String key, bool value) async {
    final prefs = await _instance();
    await prefs.setBool(key, value);
  }

  static Future<List<String>> getStringList(String key) async {
    final prefs = await _instance();
    return prefs.getStringList(key) ?? [];
  }

  static Future<void> setStringList(String key, List<String> value) async {
    final prefs = await _instance();
    await prefs.setStringList(key, value);
  }

  static Future<void> remove(String key) async {
    final prefs = await _instance();
    await prefs.remove(key);
  }

  static Future<void> clearAuth() async {
    final prefs = await _instance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('username');
  }
}
