import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'dialect_converter.dart';

/// comments.json 仕様（例）
/// {
///   "犬_元気": [ { "species": "犬", "personality": "元気", "text": "..." }, ... ],
///   "犬_おっとり": [ ... ],
///   "猫_元気": [ ... ],
///   ...
/// }
///
/// 既存の入れ子（species -> personality -> List<String>）にもフォールバック対応。
class CommentsLoader {
  static final CommentsLoader _i = CommentsLoader._internal();
  factory CommentsLoader() => _i;
  CommentsLoader._internal();

  Map<String, dynamic>? _db;
  final _rand = Random();

  static const Map<String, String> _speciesToJsonKey = {
    '犬':'犬','猫':'猫','うさぎ':'ウサギ','鳥':'鳥','ゾウ':'象','ハムスター':'ハムスター',
    'フクロモモンガ':'フクロモモンガ','フェレット':'フェレット','ウーパールーパー':'ウーパールーパー',
    '馬':'馬','パンダ':'パンダ','牛':'牛','サル':'猿',
  };

  static const List<String> _allowedPersonalities = [
    '元気','おっとり','クール','甘えん坊','臆病','おしゃべり','やんちゃ'
  ];

  Future<void> load() async {
    if (_db != null) return;
    final raw = await rootBundle.loadString('assets/comments.json');
    _db = json.decode(raw) as Map<String, dynamic>;
  }

  /// 代表API：重み付きでコメント1件取得（必ず text を返す）
  /// - 選択性格 65% / その他性格 35%
  /// - 方言変換, プレースホルダ埋め込み
  Future<String> getComment({
    required String species,
    required String personality,
    required String owner,
    required String pet,
    String dialect = '標準語',
  }) async {
    await load();
    final db = _db ?? {};
    final sKey = _speciesToJsonKey[species] ?? species;

    // 性格を 65/35 で決定
    final bool useChosen = _rand.nextDouble() < 0.65;
    final String pKey = _normalizePersonality(personality);
    final List<String> others = _allowedPersonalities.where((p) => p != pKey).toList();
    final String chosenPersonality = useChosen ? pKey : (others..shuffle(_rand)).first;

    // まずは "種_性格" フラットキー
    final key = '${sKey}_$chosenPersonality';
    List<dynamic>? list = _asList(db[key]);

    // 種一致の他性格・入れ子形式などフォールバック
    list ??= _firstSpeciesAnyPersonality(db, sKey);
    list ??= _nestedFallback(db, sKey, chosenPersonality);
    list ??= _pickAnyList(db);

    final String rawText = _extractTextFrom(list);
    final String withDialect = DialectConverter.convert(rawText, dialect);
    return _fillPlaceholders(withDialect, owner, pet);
  }

  // ===== helpers =====
  String _normalizePersonality(String p) =>
      _allowedPersonalities.contains(p) ? p : '元気';

  List<dynamic>? _asList(dynamic v) {
    if (v is List) return v;
    if (v is Map && v['list'] is List) return (v['list'] as List).cast<dynamic>();
    return null;
  }

  List<dynamic>? _firstSpeciesAnyPersonality(Map<String, dynamic> db, String sKey) {
    // 例: 犬_元気 / 犬_おっとり ... のいずれか最初を返す
    for (final e in db.entries) {
      if (e.key.startsWith('${sKey}_')) { // ← 修正ポイント（タイポ修正）
        final l = _asList(e.value);
        if (l != null && l.isNotEmpty) return l;
      }
    }
    return null;
  }

  List<dynamic>? _nestedFallback(Map<String, dynamic> db, String sKey, String pKey) {
    final spec = db[sKey];
    if (spec is Map<String, dynamic>) {
      // species -> personality -> List
      final l1 = _asList(spec[pKey]);
      if (l1 != null && l1.isNotEmpty) return l1;
      // 性格不一致なら species 下の最初の List
      for (final v in spec.values) {
        final l2 = _asList(v);
        if (l2 != null && l2.isNotEmpty) return l2;
      }
    }
    return null;
  }

  List<dynamic>? _pickAnyList(Map<String, dynamic> db) {
    for (final v in db.values) {
      final l = _asList(v);
      if (l != null && l.isNotEmpty) return l;
      if (v is Map<String, dynamic>) {
        for (final vv in v.values) {
          final ll = _asList(vv);
          if (ll != null && ll.isNotEmpty) return ll;
        }
      }
    }
    return null;
  }

  String _extractTextFrom(List<dynamic>? list) {
    if (list == null || list.isEmpty) return '今日は静かみたい…';
    final any = list[_rand.nextInt(list.length)];
    if (any is String) return any;
    if (any is Map && any['text'] is String) return any['text'] as String;
    return any.toString(); // 最後の砦（ただし今回の仕様では基本ここに来ない）
  }

  String _fillPlaceholders(String text, String owner, String pet) {
    return text.replaceAll('{owner}', owner).replaceAll('{pet}', pet);
  }
}
