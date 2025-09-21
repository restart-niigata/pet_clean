import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 1つの日記エントリー（会話履歴）を表すデータクラス
class DiaryEntry {
  final String comment;    // その時のセリフ
  final String mood;       // その時の気分
  final DateTime timestamp;  // その時の日時

  DiaryEntry({
    required this.comment,
    required this.mood,
    required this.timestamp,
  });

  // データクラスをJSON形式に変換するためのファクトリコンストラクタ
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      comment: json['comment'],
      mood: json['mood'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  // データクラスをJSON形式に変換するメソッド
  Map<String, dynamic> toJson() {
    return {
      'comment': comment,
      'mood': mood,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// 日記データの保存と読み込みを担当するサービスクラス
class DiaryService {
  DiaryService._privateConstructor();
  static final DiaryService instance = DiaryService._privateConstructor();

  // SharedPreferencesで使うためのキー
  static const _keyDiaryEntries = 'diaryEntries';

  // 新しい日記エントリーを追加保存する関数
  Future<void> addDiaryEntry(DiaryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    // 1. まず現在の全日記データを読み込む
    final List<DiaryEntry> entries = await loadDiaryEntries();
    // 2. 新しいエントリーをリストの先頭に追加
    entries.insert(0, entry);
    // 3. リスト全体をJSON文字列に変換
    final String jsonString = json.encode(entries.map((e) => e.toJson()).toList());
    // 4. 変換した文字列を保存
    await prefs.setString(_keyDiaryEntries, jsonString);
    print('✅ 新しい日記を保存しました。');
  }

  // 全ての日記データを読み込む関数
  Future<List<DiaryEntry>> loadDiaryEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_keyDiaryEntries);

    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => DiaryEntry.fromJson(json)).toList();
    } else {
      // データがなければ空のリストを返す
      return [];
    }
  }

  // 全ての日記データを削除する関数（将来的に使うかも）
  Future<void> clearDiary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDiaryEntries);
    print('🗑️ 全ての日記データを削除しました。');
  }
}