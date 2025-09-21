import 'package:shared_preferences/shared_preferences.dart';

class UserData {
  final String petType;
  final String personality;
  final String petName;
  final String ownerName;

  UserData({
    required this.petType,
    required this.personality,
    required this.petName,
    required this.ownerName,
  });
}

class UserDataService {
  UserDataService._privateConstructor();
  static final UserDataService instance = UserDataService._privateConstructor();

  static const _keyPetType = 'petType';
  static const _keyPersonality = 'personality';
  static const _keyPetName = 'petName';
  static const _keyOwnerName = 'ownerName';
  // ★★★ 1. 会話履歴を保存するための新しいキーを追加 ★★★
  static const _keyCommentHistory = 'commentHistory';


  Future<void> saveUserData(UserData userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPetType, userData.petType);
    await prefs.setString(_keyPersonality, userData.personality);
    await prefs.setString(_keyPetName, userData.petName);
    await prefs.setString(_keyOwnerName, userData.ownerName);
    print('✅ ユーザーデータを保存しました。');
  }

  Future<UserData?> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!prefs.containsKey(_keyPetName)) {
      print('ℹ️ 保存されたユーザーデータはありませんでした。');
      return null;
    }

    final petType = prefs.getString(_keyPetType)!;
    final personality = prefs.getString(_keyPersonality)!;
    final petName = prefs.getString(_keyPetName)!;
    final ownerName = prefs.getString(_keyOwnerName)!;

    print('✅ 保存されたユーザーデータを読み込みました。');
    return UserData(
      petType: petType,
      personality: personality,
      petName: petName,
      ownerName: ownerName,
    );
  }
  
  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPetType);
    await prefs.remove(_keyPersonality);
    await prefs.remove(_keyPetName);
    await prefs.remove(_keyOwnerName);
    // 履歴も一緒に削除する
    await prefs.remove(_keyCommentHistory);
    print('🗑️ ユーザーデータを削除しました。');
  }

  // ★★★ 2. ここからが新しく追加した関数 ★★★

  /// 表示したセリフを履歴に追加する関数
  Future<void> addCommentToHistory(String comment) async {
    final prefs = await SharedPreferences.getInstance();
    // まず現在の履歴を読み込む
    List<String> history = prefs.getStringList(_keyCommentHistory) ?? [];
    // 新しいセリフをリストの先頭に追加
    history.insert(0, comment);
    // 履歴が200件を超えたら、一番古いものを削除
    if (history.length > 200) {
      history = history.sublist(0, 200);
    }
    // 更新した履歴を保存
    await prefs.setStringList(_keyCommentHistory, history);
  }

  /// 保存されている会話履歴のリストを取得する関数
  Future<List<String>> getCommentHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyCommentHistory) ?? [];
  }

  /// 全ての会話履歴を削除する関数（リセット機能などで使用）
  Future<void> clearCommentHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCommentHistory);
  }
}