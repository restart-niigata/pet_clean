class NameUtil {
  static String getNickname(String name, String personality) {
    switch (personality) {
      case '甘えん坊':
        return '$nameちゃん';
      case 'ツンデレ':
        return '$name様';
      case '元気いっぱい':
        return '$nameっち';
      case 'おっとり':
        return '$nameさん';
      case 'わんぱく':
        return '$nameくん';
      case 'マイペース':
        return '$nameたん';
      case '好奇心旺盛':
        return '$name隊長';
      case '賢い':
        return '$name先生';
      default:
        return name;
    }
  }
}
