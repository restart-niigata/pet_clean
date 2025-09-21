// lib/data/species_assets.dart
const Map<String, String> _speciesToFile = {
  '犬': 'dog.png',
  '猫': 'cat.png',
  'うさぎ': 'rabbit.png',
  '鳥': 'bird.png',
  'ゾウ': 'other_elephant.png', // 画像名に合わせてother_を使用
  'ハムスター': 'hamster.png',
  'フクロモモンガ': 'sugar_glider.png',
  'フェレット': 'ferret.png',
  'ウーパールーパー': 'axolotl.png',
  '馬': 'horse.png',
  'パンダ': 'other_panda.png',
  '牛': 'other_cow.png',
  'サル': 'other_monkey.png',
};

String assetForSpecies(String jpName) {
  final file = _speciesToFile[jpName];
  if (file == null) return 'assets/images/top_pet.png'; // フォールバック
  return 'assets/images/$file';
}
