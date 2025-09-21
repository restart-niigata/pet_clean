import 'package:shared_preferences/shared_preferences.dart';

class HistoryStorage {
  final String _key = 'comment_history';

  Future<void> addHistory(String comment) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.add(comment);
    await prefs.setStringList(_key, list);
  }

  Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
