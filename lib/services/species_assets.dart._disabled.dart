const speciesList = <String>[
  '犬','猫','ウサギ','鳥','象','ハムスター',
  'フクロモモンガ','フェレット','ウーパールーパー',
  '馬','パンダ','牛','猿',
];

String speciesImage(String name) {
  switch (name) {
    case '犬': return 'assets/images/dog.png';
    case '猫': return 'assets/images/cat.png';
    case 'ウサギ': return 'assets/images/rabbit.png';
    case '鳥': return 'assets/images/bird.png';
    case '象': return 'assets/images/other_elephant.png';
    case 'ハムスター': return 'assets/images/hamster.png';
    case 'フクロモモンガ': return 'assets/images/sugar_glider.png';
    case 'フェレット': return 'assets/images/ferret.png';
    case 'ウーパールーパー': return 'assets/images/axolotl.png';
    case '馬': return 'assets/images/horse.png';
    case 'パンダ': return 'assets/images/other_panda.png';
    case '牛': return 'assets/images/other_cow.png';
    case '猿': return 'assets/images/other_monkey.png';
    default: return 'assets/images/other_panda.png';
  }
}

/// JSONキー用の正規化（過去資産に合わせる）
const speciesToJsonKey = <String, String>{
  '犬':'犬','猫':'猫','ウサギ':'ウサギ','鳥':'鳥','象':'象','ハムスター':'ハムスター',
  'フクロモモンガ':'フクロモモンガ','フェレット':'フェレット','ウーパールーパー':'ウーパールーパー',
  '馬':'馬','パンダ':'パンダ','牛':'牛','猿':'猿',
};
