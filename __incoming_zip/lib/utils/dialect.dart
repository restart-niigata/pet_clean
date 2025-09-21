// lib/utils/dialect.dart
// 与えられた標準文を、選択された方言風に軽く変換します（文末だけ差し替え）

String applyDialect(String dialect, String standardText) {
  // 句点は残す（例：「だよ。」→「やで。」）
  String replaceEnding(String s, String to) {
    final reg = RegExp(r'(だよ|だね|です|だ)([。.!?？]?)$');
    return s.replaceAllMapped(reg, (m) {
      final punctuation = m.group(2) ?? '';
      return '$to$punctuation';
    });
  }

  switch (dialect) {
    case '関西弁':
      return replaceEnding(standardText, 'やで');
    case '新潟弁':
      // 正しく「だっけさ」に（③）
      return replaceEnding(standardText, 'だっけさ');
    case '福岡弁':
      return replaceEnding(standardText, 'たい');
    case '広島弁':
      return replaceEnding(standardText, 'じゃけぇ');
    case '福島弁':
      return replaceEnding(standardText, 'だべ');
    case '秋田弁':
      return replaceEnding(standardText, 'だす');
    case '名古屋弁':
      return replaceEnding(standardText, 'だがね');
    case '金沢弁':
      return replaceEnding(standardText, 'やぞいね');
    case '標準語':
    default:
      return standardText;
  }
}
