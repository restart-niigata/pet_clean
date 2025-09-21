import 'package:shared_preferences/shared_preferences.dart';

class ProfileStore {
  static const _kUserName = 'profile.userName';
  static const _kUserKana = 'profile.userKana';
  static const _kUserNote = 'profile.userNote';

  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserName, name);
  }

  static Future<void> saveUserKana(String kana) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKana, kana);
  }

  static Future<void> saveUserNote(String note) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserNote, note);
  }

  static Future<String?> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserName);
  }

  static Future<String?> loadUserKana() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserKana);
  }

  static Future<String?> loadUserNote() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserNote);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserName);
    await prefs.remove(_kUserKana);
    await prefs.remove(_kUserNote);
  }
}
