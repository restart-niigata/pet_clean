// lib/services/dialect_service.dart

/// 方言の超簡易変換。
/// {owner},{pet} 等は呼び出し側で置換済みを想定。ここでは語尾等だけを置換。
class DialectService {
  static String apply(String dialect, String text) {
    switch (dialect) {
      case '関西弁':
        return _swap(text, {
          'だよ': 'やで',
          'です': 'やで',
          'だね': 'やな',
          'かな': 'かなぁ',
        });
      case '新潟弁':
        // 「だっけさ」に統一（以前の誤り『だっけさっけさ』は使わない）
        return _swap(text, {
          'だよ': 'だっけさ',
          'です': 'だっけさ',
          'だね': 'だっけさね',
        });
      case '福岡弁':
        return _swap(text, {
          'だよ': 'たい',
          'です': 'たい',
          'だね': 'っちゃね',
        });
      case '広島弁':
        return _swap(text, {
          'だよ': 'じゃけぇ',
          'です': 'じゃ',
          'だね': 'じゃね',
        });
      case '福島弁':
        return _swap(text, {
          'だよ': 'だべ',
          'です': 'だべ',
          'だね': 'だべね',
        });
      case '秋田弁':
        return _swap(text, {
          'だよ': 'だす',
          'です': 'だす',
          'だね': 'だすな',
        });
      case '名古屋弁':
        return _swap(text, {
          'だよ': 'だがね',
          'です': 'だがね',
          'だね': 'だがね',
        });
      case '金沢弁':
        return _swap(text, {
          'だよ': 'じょ',
          'です': 'じょ',
          'だね': 'じょね',
        });
      default: // 標準語
        return text;
    }
  }

  static String _swap(String src, Map<String, String> map) {
    var out = src;
    map.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }
}
