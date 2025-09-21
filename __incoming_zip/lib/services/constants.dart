class Dialects {
  static const standard = '標準語';
  static const kansai = '関西弁';
  static const nigata = '新潟弁';
  static const fukuoka = '福岡弁';
  static const hiroshima = '広島弁';
  static const fukushima = '福島弁';
  static const akita = '秋田弁';
  static const nagoya = '名古屋弁';
  static const kanazawa = '金沢弁';
  static const all = <String>[
    standard,kansai,nigata,fukuoka,hiroshima,fukushima,akita,nagoya,kanazawa
  ];
}

const personalities = <String>[
  '元気','おっとり','クール','甘えん坊','臆病','おしゃべり','やんちゃ',
];

/// コメント表示時間の重み（秒 → 割合）
const displayDurations = <int,int>{
  5:35, 10:30, 15:25, 2:5, 30:5,
};

/// 性格の抽選重み（選択65% / その他35%を全体で配分）
Map<String,int> personalityWeights(String selected) {
  const base = 35; // 35% をその他6種に均等配分 ≒ 6ずつ（合計で65%に合わせるため選択=65）
  final map = <String,int>{ for (final p in personalities) p: 0 };
  for (final p in personalities) {
    map[p] = (p == selected) ? 65 : (35 ~/ (personalities.length-1)); // 65 / 6
  }
  // 端数調整
  final sum = map.values.reduce((a,b)=>a+b);
  if (sum != 100) {
    // 適当に選択性格へ付与
    map[selected] = map[selected]! + (100 - sum);
  }
  return map;
}
