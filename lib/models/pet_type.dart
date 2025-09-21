// lib/models/pet_type.dart
enum PetType {
  dog,
  cat,
  rabbit,
  bird,
  elephant,
  hamster,
  sugarGlider,
  ferret,
  axolotl,
  horse,
  panda,
  cow,
  monkey,
}

extension PetTypeX on PetType {
  String get label => switch (this) {
        PetType.dog         => '犬',
        PetType.cat         => '猫',
        PetType.rabbit      => 'うさぎ',
        PetType.bird        => '鳥',
        PetType.elephant    => 'ゾウ',
        PetType.hamster     => 'ハムスター',
        PetType.sugarGlider => 'フクロモモンガ',
        PetType.ferret      => 'フェレット',
        PetType.axolotl     => 'ウーパールーパー',
        PetType.horse       => '馬',
        PetType.panda       => 'パンダ',
        PetType.cow         => '牛',
        PetType.monkey      => 'サル',
      };

  /// 画像パス（実ファイル名に合わせる）
  String get iconPath => switch (this) {
        PetType.dog         => 'assets/images/dog.png',
        PetType.cat         => 'assets/images/cat.png',
        PetType.rabbit      => 'assets/images/rabbit.png',
        PetType.bird        => 'assets/images/bird.png',
        PetType.elephant    => 'assets/images/other_elephant.png',
        PetType.hamster     => 'assets/images/hamster.png',
        PetType.sugarGlider => 'assets/images/sugar_glider.png',
        PetType.ferret      => 'assets/images/ferret.png',
        PetType.axolotl     => 'assets/images/axolotl.png',
        PetType.horse       => 'assets/images/horse.png',
        PetType.panda       => 'assets/images/other_panda.png',
        PetType.cow         => 'assets/images/other_cow.png',
        PetType.monkey      => 'assets/images/other_monkey.png',
      };

  /// ペット選択画面の表示順（おすすめ順）
  static List<PetType> get orderedValues => const [
        PetType.dog,
        PetType.cat,
        PetType.rabbit,
        PetType.bird,
        PetType.elephant,
        PetType.hamster,
        PetType.sugarGlider,
        PetType.ferret,
        PetType.axolotl,
        PetType.horse,
        PetType.panda,
        PetType.cow,
        PetType.monkey,
      ];
}
