class SpecConstants {
  static const List<String> species = [
    '犬','猫','ウサギ','ハムスター','鳥（インコ・文鳥など）',
    'フクロモモンガ','フェレット','ウーパールーパー','馬','象','パンダ','牛','猿',
  ];

  static const List<String> personalities = [
    '元気','おっとり','クール','甘えん坊','臆病','おしゃべり','やんちゃ',
  ];

  static const String fallbackMessage = 'コメントが見つからないよ';
  static const double selectedPersonalityWeight = 0.65;
  static const String commentsAssetPath = 'assets/comments.json';
}
