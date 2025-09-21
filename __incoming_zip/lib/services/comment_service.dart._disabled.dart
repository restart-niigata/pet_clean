import 'dart:math';
import '../pages/top_page.dart'; // kSpeciesToJsonKey, kPersonalities を利用

class CommentService {
  CommentService._();
  static final instance = CommentService._();

  final _rand = Random();
  String? _species;
  String? _personality;
  String? _pet;
  String? _owner;
  String _dialect = '標準語';
  String? _last;

  // 本番ではデータを分割ファイルでOK。ここでは雛形で species/personality 別の簡易文を生成
  // ※ユーザー提供の正式データ(JSON)をここに流し込んでも動くようキー設計は「<種>_<性格>」
  final Map<String, List<String>> _map = {
    '犬_元気': ['{pet}は今、お散歩に行きたい気分だな','{owner}と一緒に走るとワクワクしてくるよ'],
    '犬_おっとり': ['{pet}は今、のんびりお散歩したい気分だな','{owner}の隣にいると落ち着くな'],
    '犬_クール': ['{pet}は静かに景色を見たいみたい','今日は落ち着いて歩こう'],
    '犬_甘えん坊': ['{owner}のそばにいたいな','もっと撫でてほしいな'],
    '犬_臆病': ['少しだけ怖い音がしたかも…','{owner}がいてくれたら安心だよ'],
    '犬_おしゃべり': ['ねぇねぇ、散歩行こ？','今日の出来事話したいんだ！'],
    '犬_やんちゃ': ['ボール投げて！','走り回りたい気分！'],
    // 他の種も必要なら同様に追加
  };

  void configure({
    String? species,
    String? personality,
    String? petName,
    String? ownerName,
    String? dialect,
  }) {
    _species = species;
    _personality = personality;
    _pet = petName;
    _owner = ownerName;
    if (dialect != null) _dialect = dialect;
  }

  String _keyOf(String sp, String per) => '${kSpeciesToJsonKey[sp] ?? sp}_${per}';

  String nextComment() {
    final sp = _species ?? '犬';
    final primary = _personality ?? '元気';

    // 65%: primary, 35%: others（同一種内）
    String pickPersonality() {
      final r = _rand.nextDouble();
      if (r < 0.65) return primary;
      final others = kPersonalities.where((p) => p != primary).toList();
      return others[_rand.nextInt(others.length)];
    }

    String? candidate;
    for (int i=0; i<20; i++) {
      final per = pickPersonality();
      final key = _keyOf(sp, per);
      final list = _map[key] ?? _map[_keyOf('犬','元気')]!;
      final raw = list[_rand.nextInt(list.length)];
      final text = raw.replaceAll('{pet}', _pet ?? 'ペット').replaceAll('{owner}', _owner ?? 'あなた');
      if (text != _last) {
        candidate = _applyDialect(text);
        break;
      }
    }
    _last = candidate;
    return candidate ?? (_applyDialect('いまは静かにしたい気分だよ'));
  }

  String _applyDialect(String base) {
    switch (_dialect) {
      case '関西弁': return base.replaceAll('だよ', 'やで').replaceAll('な', 'やな');
      case '新潟弁': return '$base だっけさ';
      case '福岡弁': return '$base っちゃ';
      case '広島弁': return '$base じゃけぇ';
      case '福島弁': return '$base だべ';
      case '秋田弁': return '$base だす';
      case '名古屋弁': return '$base だがね';
      case '金沢弁': return '$base やぞいね';
      default: return base;
    }
  }
}
