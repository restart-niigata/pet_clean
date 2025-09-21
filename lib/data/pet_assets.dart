// lib/data/pet_assets.dart
class PetAssets {
  // 正式リスト（仕様書準拠）
  static const List<String> species = [
    '犬',
    '猫',
    'ウサギ',
    'ハムスター',
    '鳥（インコ・文鳥など）',
    'フクロモモンガ',
    'フェレット',
    'ウーパールーパー',
    '馬',
    '象',
    'パンダ',
    '牛',
    '猿',
  ];

  // personalities も仕様書準拠に固定
  static const List<String> personalities = [
    '元気',
    'おっとり',
    'クール',
    '甘えん坊',
    '臆病',
    'おしゃべり',
    'やんちゃ',
  ];

  // 画像マップ（存在するPNGに合わせたパス）
  // ※ “その他”系は other_*.png を使用
  static const Map<String, String> speciesToAsset = {
    '犬': 'assets/images/dog.png',
    '猫': 'assets/images/cat.png',
    'ウサギ': 'assets/images/rabbit.png',
    'ハムスター': 'assets/images/hamster.png',
    '鳥（インコ・文鳥など）': 'assets/images/bird.png',
    'フクロモモンガ': 'assets/images/sugar_glider.png',
    'フェレット': 'assets/images/ferret.png',
    'ウーパールーパー': 'assets/images/axolotl.png',
    '馬': 'assets/images/horse.png',
    '象': 'assets/images/other_elephant.png',
    'パンダ': 'assets/images/other_panda.png',
    '牛': 'assets/images/other_cow.png',
    '猿': 'assets/images/other_monkey.png',
  };

  // 安全にパスを取得（なければ app_icon を返す）
  static String imageOf(String jpSpecies) {
    return speciesToAsset[jpSpecies] ?? 'assets/images/app_icon.png';
  }
}
