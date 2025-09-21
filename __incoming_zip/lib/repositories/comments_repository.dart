// lib/repositories/comments_repository.dart
import 'dart:async';

/// 必ず非空を返すフォールバック実装。
/// クラス名は CommentsRepository（複数形）で TalkPage 側と揃える。
class CommentsRepository {
  static final CommentsRepository instance = CommentsRepository._internal();
  CommentsRepository._internal();
  factory CommentsRepository() => instance;

  // フォールバックテーブル
  static const Map<String, List<String>> _table = {
    '*::*': [
      '今日はとっても良い日だワン！',
      'ごはんの前に、ちょっと運動しよう！',
      '深呼吸して、リラックスしよ～',
    ],
    'dog::*': [
      'お散歩の時間だワン！',
      'きみが大好き！尻尾ぶんぶん！',
      'お水をちゃんと飲もうね～',
    ],
    'cat::*': [
      'ふわぁ…お昼寝タイムにゃ。',
      '撫でられるの、ちょっと嬉しいかも…？',
      '今日は窓辺が気持ちいいにゃ。',
    ],
    'rabbit::*': [
      'もぐもぐ…野菜は正義！',
      'ぴょん！少し跳ねてリフレッシュ♪',
      '静かな時間も悪くないね～',
    ],
    'hamster::*': [
      '回し車でダッシュ！',
      'ほっぺに幸せチャージ！',
      '小さくても元気いっぱい！',
    ],
    'bird::*': [
      'チュン♪朝のあいさつ！',
      '羽を伸ばしてストレッチ～',
      '高いところから見渡すの好き！',
    ],
    'dog::genki': [
      '全力で遊ぶ準備OK！',
      '走って走って、もっと走るワン！',
    ],
    'cat::otsumeya': [
      '今日は箱の中が落ち着くにゃ。',
      '静かに見守っててほしいにゃ。',
    ],
  };

  // 既存コードがどちらを呼んでも動くように両方実装
  Future<List<String>> getComments({
    required String petId,
    required String personalityId,
  }) async =>
      _resolve(petId, personalityId);

  Future<List<String>> fetchComments({
    required String petId,
    required String personalityId,
  }) async =>
      _resolve(petId, personalityId);

  Future<List<String>> _resolve(String petId, String personalityId) async {
    final keyExact = '$petId::$personalityId';
    final exact = _table[keyExact];
    if (exact != null && exact.isNotEmpty) return exact;

    final keyPetAny = '$petId::*';
    final petAny = _table[keyPetAny];
    if (petAny != null && petAny.isNotEmpty) return petAny;

    return _table['*::*']!;
  }
}
