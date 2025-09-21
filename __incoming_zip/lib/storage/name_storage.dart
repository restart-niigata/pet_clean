import 'package:shared_preferences/shared_preferences.dart';

class NameStorage {
  final String _key = 'user_name';

  Future<void> saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, name);
  }

  Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> clearName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
