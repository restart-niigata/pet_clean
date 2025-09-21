import 'dart:math';

final _rnd = Random();

/// 仕様：①3秒35% ②5秒30% ③10秒25% ④15秒5% ⑤20秒5%
int pickCommentSec() {
  final v = _rnd.nextDouble();
  if (v < 0.35) return 3;
  if (v < 0.65) return 5;
  if (v < 0.90) return 10;
  if (v < 0.95) return 15;
  return 20;
}
