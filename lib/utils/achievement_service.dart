import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// (Achievementクラス、Anniversaryクラスは変更なし)
class Achievement {
  final String id;
  final String name;
  final String description;
  bool isUnlocked;
  Achievement({required this.id, required this.name, required this.description, this.isUnlocked = false});
}

class Anniversary {
  final String name;
  final DateTime date;
  Anniversary({required this.name, required this.date});
}

class AchievementService {
  AchievementService._privateConstructor();
  static final AchievementService instance = AchievementService._privateConstructor();

  static const _keyUnlockedAchievements = 'unlockedAchievements';
  static const _keyAnniversaries = 'anniversaries';

  final List<Achievement> _allAchievements = [
    Achievement(id: 'first_diary', name: '最初の記録', description: '初めて会話を日記に保存した'),
    Achievement(id: 'share_1', name: '自慢の第一歩', description: '初めて会話をSNSで共有した'),
    Achievement(id: 'login_7', name: 'ズッ友の始まり', description: '7日間、連続でアプリを起動した（※未実装）'),
  ];

  // ★★★ ここを改造しました！ ★★★
  /// 実績を解除する。新しく解除された場合は true を返す
  Future<bool> unlockAchievement(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> unlockedIds = prefs.getStringList(_keyUnlockedAchievements) ?? [];
    
    // もし、まだ解除されていなかったら...
    if (!unlockedIds.contains(id)) {
      unlockedIds.add(id);
      await prefs.setStringList(_keyUnlockedAchievements, unlockedIds);
      print('🏆 実績解除: $id');
      return true; // ★ 新しく解除したので true を返す
    }
    
    // すでに解除済みだった場合
    return false; // ★ 解除済みなので false を返す
  }

  Future<List<String>> getUnlockedAchievementIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyUnlockedAchievements) ?? [];
  }

  Future<List<Achievement>> getAllAchievementsWithStatus() async {
    final unlockedIds = await getUnlockedAchievementIds();
    for (var ach in _allAchievements) {
      if (unlockedIds.contains(ach.id)) {
        ach.isUnlocked = true;
      }
    }
    return _allAchievements;
  }
  
  // (saveAnniversaries以下の関数は変更ありません)
  Future<void> saveAnniversaries(List<Anniversary> anniversaries) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> stringList = anniversaries.map((a) => '${a.name},${a.date.toIso8601String()}').toList();
    await prefs.setStringList(_keyAnniversaries, stringList);
  }

  Future<List<Anniversary>> loadAnniversaries() async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = prefs.getStringList(_keyAnniversaries) ?? [];
    return stringList.map((s) {
      final parts = s.split(',');
      return Anniversary(name: parts[0], date: DateTime.parse(parts[1]));
    }).toList();
  }
  
  Future<List<Anniversary>> getTodaysAnniversaries() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final anniversaries = await loadAnniversaries();
    return anniversaries.where((a) => a.date.month == today.month && a.date.day == today.day).toList();
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUnlockedAchievements);
    await prefs.remove(_keyAnniversaries);
  }
}