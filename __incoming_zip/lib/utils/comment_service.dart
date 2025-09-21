import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:pet_talker_v2/utils/achievement_service.dart';

class CommentService {
  CommentService._privateConstructor();
  static final CommentService instance = CommentService._privateConstructor();

  Map<String, dynamic>? _allComments;

  Future<void> loadComments() async {
    if (_allComments != null) return;
    try {
      final jsonString = await rootBundle.loadString('assets/templates/comments.json');
      _allComments = json.decode(jsonString);
      print('✅ 新しい構造のcomments.jsonの読み込みと解析が正常に完了しました。');
    } catch (e) {
      print('❌ comments.jsonの読み込みまたは解析に失敗しました: $e');
      _allComments = {};
    }
  }

  List<String> getAvailablePersonalities() {
    if (_allComments == null || _allComments!['喜び'] == null) return [];
    return (_allComments!['喜び'] as Map<String, dynamic>).keys.where((key) => key != 'common').toList();
  }
  
  final Map<String, List<String>> _moodToEmotionsMap = {
    'いつも通り': ['喜び', '期待', '退屈してる', '哲学タイム', '運命を受け入れた'],
    'ご機嫌さん': ['喜び', '大好き', '変なテンション', '自分がアイドルだと思ってる', 'ほめてほしい'],
    '不機嫌': ['不満', 'キレ芸', '謝ってほしい', 'そっけなくされた', 'お風呂嫌い'],
    '体調が悪そう': ['不安', 'ごめんなさい', '存在意義を考えている', 'ネガティヴ'],
    'ぼーっとしてる': ['眠いけど寝たくない', '宇宙を感じる', '哲学バースト', 'この世の理を悟った'],
    'さみし気': ['寂しさ', '忘れられてる気がする', 'やきもちやいてる', '嫉妬してる'],
    '甘えん坊': ['大好き', 'もっと触って', '信じてる', 'ほめてほしい']
  };

  Future<String> getRandomComment({
    required String personality,
    required String emotion, 
    required String ownerName,
    // ★★★ 1. 会話履歴を引数で受け取るように変更 ★★★
    required List<String> history, 
  }) async {
    if (_allComments == null) await loadComments();

    // (記念日とレアコメントの処理は変更なし)
    final todaysAnniversaries = await AchievementService.instance.getTodaysAnniversaries();
    if (todaysAnniversaries.isNotEmpty) {
      final anniversary = todaysAnniversaries.first;
      return '🎉今日は「${anniversary.name}」だね！特別な日だから、一緒にお祝いしよう！';
    }
    
    if (Random().nextDouble() < 0.15) {
      final unlockedIds = await AchievementService.instance.getUnlockedAchievementIds();
      if (unlockedIds.isNotEmpty) {
        final randomAchievementId = unlockedIds[Random().nextInt(unlockedIds.length)];
        final List<dynamic>? rareComments = _allComments!['__rare_comments']?[randomAchievementId];
        if (rareComments != null && rareComments.isNotEmpty) {
          return rareComments[Random().nextInt(rareComments.length)] as String;
        }
      }
    }
    
    final List<String>? emotionCandidates = _moodToEmotionsMap[emotion];
    if (emotionCandidates == null || emotionCandidates.isEmpty) return '...';
    final selectedEmotion = emotionCandidates[Random().nextInt(emotionCandidates.length)];

    final Map<String, dynamic>? emotionData = _allComments![selectedEmotion];
    if (emotionData == null) return '...（感情データが見つかりません）';

    List<String> commentCandidates = [];

    if (emotionData['common'] != null) {
      commentCandidates.addAll(List<String>.from(emotionData['common']));
    }
    if (emotionData[personality] != null) {
      commentCandidates.addAll(List<String>.from(emotionData[personality]));
    }

    // ★★★ 2. 履歴に含まれないセリフだけを抽出 ★★★
    List<String> filteredCandidates = commentCandidates.where((comment) => !history.contains(comment)).toList();

    // もし全てのセリフが履歴にあったら、やむを得ず履歴からも選ぶ
    if (filteredCandidates.isEmpty) {
      filteredCandidates = commentCandidates;
    }

    if (filteredCandidates.isEmpty) {
      return '...（考え中）';
    }
    
    String randomComment = filteredCandidates[Random().nextInt(filteredCandidates.length)];
    
    if (Random().nextDouble() < 0.4) {
      randomComment = "$ownerName、" + randomComment;
    }

    return randomComment;
  }
}