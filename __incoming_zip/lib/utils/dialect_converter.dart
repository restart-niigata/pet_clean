/// DialectConverter
/// - 標準語ベースの文言を各方言へ変換する層
/// - 「語彙置換」＋「文末置換（終止形/丁寧形/希望・推量）」を適用
/// - 置換は軽量で可逆ではありません。必要に応じて辞書を拡張してください。
class DialectConverter {
  static String convert(String text, String dialect) {
    switch (dialect) {
      case '関西弁':
        return _convert(text, _kansaiLex, _kansaiEndings);
      case '新潟弁':
        return _convert(text, _niigataLex, _niigataEndings);
      case '福岡弁':
        return _convert(text, _fukuokaLex, _fukuokaEndings);
      case '広島弁':
        return _convert(text, _hiroshimaLex, _hiroshimaEndings);
      case '福島弁':
        return _convert(text, _fukushimaLex, _fukushimaEndings);
      case '秋田弁':
        return _convert(text, _akitaLex, _akitaEndings);
      case '名古屋弁':
        return _convert(text, _nagoyaLex, _nagoyaEndings);
      case '金沢弁':
        return _convert(text, _kanazawaLex, _kanazawaEndings);
      case '標準語':
      default:
        return text;
    }
  }

  /// 文を句点/改行で区切って各文に置換を適用
  static String _convert(
    String src,
    Map<String, String> lex,
    List<_EndingRule> endings,
  ) {
    // プレースホルダは保持したいので一時避難（置換衝突防止）
    const phOwner = '\u0001OWNER\u0001';
    const phPet = '\u0001PET\u0001';
    var work = src.replaceAll('{owner}', phOwner).replaceAll('{pet}', phPet);

    // 語彙置換（長いキー優先）
    final keys = lex.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      work = work.replaceAll(k, lex[k]!);
    }

    // 文末置換
    final sentences = work.split(RegExp(r'(?<=[。！？!?])'));
    for (var i = 0; i < sentences.length; i++) {
      var s = sentences[i].trimRight();
      if (s.isEmpty) continue;
      // 句読点抜きの末尾を見て順に評価
      for (final rule in endings) {
        final out = rule.apply(s);
        if (out != null) {
          s = out;
          break;
        }
      }
      sentences[i] = s;
    }
    work = sentences.join('');

    // プレースホルダ復元
    return work.replaceAll(phOwner, '{owner}').replaceAll(phPet, '{pet}');
  }
}

/// 文末変換ルール
class _EndingRule {
  final RegExp matcher;
  final String replace;
  _EndingRule(this.matcher, this.replace);

  String? apply(String s) {
    if (!matcher.hasMatch(s)) return null;
    return s.replaceAll(matcher, replace);
  }
}

/* ==== 方言辞書（最小でも体感差が出る語彙） ==== */

final _commonPolite = <RegExp, String>{
  RegExp(r'ます(?=[。！？!?]|$)'): '', // 文末「ます。」→削る前提で各方言に置換
  RegExp(r'です(?=[。！？!?]|$)'): '', // 文末「です。」→削る
};

final Map<String, String> _kansaiLex = {
  'とても': 'めっちゃ',
  '本当': 'ほんま',
  'すごく': 'めっちゃ',
  '〜かな': '〜やろか',
};
final List<_EndingRule> _kansaiEndings = [
  _EndingRule(RegExp(r'だよ(?=[。！？!?]|$)'), 'やで'),
  _EndingRule(RegExp(r'だな(?=[。！？!?]|$)'), 'やな'),
  _EndingRule(RegExp(r'だ(?=[。！？!?]|$)'), 'やねん'),
  _EndingRule(RegExp(r'たい(?=[。！？!?]|$)'), 'たいねん'),
  ..._commonPolite.entries.map((e) => _EndingRule(e.key, 'やで')),
];

final Map<String, String> _niigataLex = {
  'とても': 'がっと',
};
final List<_EndingRule> _niigataEndings = [
  _EndingRule(RegExp(r'だよ(?=[。！？!?]|$)'), 'だすけ'),
  _EndingRule(RegExp(r'だな(?=[。！？!?]|$)'), 'だがね'),
  _EndingRule(RegExp(r'だ(?=[。！？!?]|$)'), 'だがよ'),
  ..._commonPolite.entries.map((e) => _EndingRule(e.key, 'だっけさ')),
];

final Map<String, String> _fukuokaLex = {
  '本当': 'ほんとー',
};
final List<_EndingRule> _fukuokaEndings = [
  _EndingRule(RegExp(r'だよ(?=[。！？!?]|$)'), 'っちゃ'),
  _EndingRule(RegExp(r'だな(?=[。！？!?]|$)'), 'たいね'),
  _EndingRule(RegExp(r'だ(?=[。！？!?]|$)'), 'ったい'),
  _EndingRule(RegExp(r'たい(?=[。！？!?]|$)'), 'たかいな'),
  ..._commonPolite.entries.map((e) => _EndingRule(e.key, 'っちゃ')),
];

final Map<String, String> _hiroshimaLex = {
  'とても': 'ぶち',
};
final List<_EndingRule> _hiroshimaEndings = [
  _EndingRule(RegExp(r'だよ(?=[。！？!?]|$)'), 'じゃけぇ'),
  _EndingRule(RegExp(r'だな(?=[。！？!?]|$)'), 'じゃな'),
  _EndingRule(RegExp(r'だ(?=[。！？!?]|$)'), 'じゃ'),
  _EndingRule(RegExp(r'たい(?=[。！？!?]|$)'), 'たいんよ'),
  ..._commonPolite.entries.map((e) => _EndingRule(e.key, 'じゃけぇ')),
];

final Map<String, String> _fukushimaLex = {};
final List<_EndingRule> _fukushimaEndings = [
  _EndingRule(RegExp(r'だよ(?=[。！？!?]|$)'), 'だべ'),
  _EndingRule(RegExp(r'だな(?=[。！？!?]|$)'), 'だなべ'),
  _EndingRule(RegExp(r'だ(?=[。！？!?]|$)'), 'だべ'),
  ..._commonPolite.entries.map((e) => _EndingRule(e.key, 'だべ')),
];

final Map<String, String> _akitaLex = {};
final List<_EndingRule> _akitaEndings = [
  _EndingRule(RegExp(r'だよ(?=[。！？!?]|$)'), 'だべさ'),
  _EndingRule(RegExp(r'だな(?=[。！？!?]|$)'), 'だなべさ'),
  _EndingRule(RegExp(r'だ(?=[。！？!?]|$)'), 'だべさ'),
  ..._commonPolite.entries.map((e) => _EndingRule(e.key, 'だべさ')),
];

final Map<String, String> _nagoyaLex = {
  'とても': 'でら',
};
final List<_EndingRule> _nagoyaEndings = [
  _EndingRule(RegExp(r'だよ(?=[。！？!?]|$)'), 'だがね'),
  _EndingRule(RegExp(r'だな(?=[。！？!?]|$)'), 'だがねぇ'),
  _EndingRule(RegExp(r'だ(?=[。！？!?]|$)'), 'だがね'),
  ..._commonPolite.entries.map((e) => _EndingRule(e.key, 'だがね')),
];

final Map<String, String> _kanazawaLex = {};
final List<_EndingRule> _kanazawaEndings = [
  _EndingRule(RegExp(r'だよ(?=[。！？!?]|$)'), 'やちゃ'),
  _EndingRule(RegExp(r'だな(?=[。！？!?]|$)'), 'やちゃな'),
  _EndingRule(RegExp(r'だ(?=[。！？!?]|$)'), 'やちゃ'),
  ..._commonPolite.entries.map((e) => _EndingRule(e.key, 'やちゃ')),
];
