import 'package:flutter/foundation.dart';

@immutable
class PetTypeItem {
  final String key;        // 内部キー
  final String labelJa;    // 表示名
  final String assetPath;  // 画像
  const PetTypeItem(this.key, this.labelJa, this.assetPath);
}

@immutable
class PersonalityItem {
  final String key;
  final String labelJa;
  const PersonalityItem(this.key, this.labelJa);
}

/// 仕様書どおりのペット種類
class AppSpecPetCatalog {
  static const list = <PetTypeItem>[
    PetTypeItem('dog',         '犬',              'assets/images/dog.png'),
    PetTypeItem('cat',         '猫',              'assets/images/cat.png'),
    PetTypeItem('rabbit',      'うさぎ',          'assets/images/rabbit.png'),
    PetTypeItem('bird',        '鳥',              'assets/images/bird.png'),
    PetTypeItem('elephant',    'ゾウ',            'assets/images/other_elephant.png'),
    PetTypeItem('hamster',     'ハムスター',      'assets/images/hamster.png'),
    PetTypeItem('sugarGlider', 'フクロモモンガ',  'assets/images/sugar_glider.png'),
    PetTypeItem('ferret',      'フェレット',      'assets/images/ferret.png'),
    PetTypeItem('axolotl',     'ウーパールーパー','assets/images/axolotl.png'),
    PetTypeItem('horse',       '馬',              'assets/images/horse.png'),
    PetTypeItem('panda',       'パンダ',          'assets/images/other_panda.png'),
    PetTypeItem('cow',         '牛',              'assets/images/other_cow.png'),
    PetTypeItem('monkey',      'サル',            'assets/images/other_monkey.png'),
  ];
}

/// 仕様書どおりの性格6種
class AppSpecPersonalityCatalog {
  static const list = <PersonalityItem>[
    PersonalityItem('genki',   '元気'),
    PersonalityItem('ottori',  'おっとり'),
    PersonalityItem('cool',    'クール'),
    PersonalityItem('amaenbo', '甘えん坊'),
    PersonalityItem('okubyo',  '臆病'),
    PersonalityItem('oshaberi','おしゃべり'),
  ];
}
