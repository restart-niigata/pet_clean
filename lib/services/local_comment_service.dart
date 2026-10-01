import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class LocalCommentService {
  const LocalCommentService({Future<String> Function()? assetLoader})
      : _assetLoader = assetLoader;

  final Future<String> Function()? _assetLoader;

  Future<List<String>> load({
    required String species,
    required String personality,
    required String ownerName,
    required String petName,
  }) async {
    final source = await (_assetLoader?.call() ??
        rootBundle.loadString('assets/comments.json'));
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) return const [];
    final entries = decoded['${species}_$personality'];
    if (entries is! List) return const [];

    final comments = entries
        .whereType<Map>()
        .where((entry) => entry['species'] == species)
        .where((entry) => entry['personality'] == personality)
        .map((entry) => entry['text'])
        .whereType<String>()
        // 独り言に見えても、実際には飼い主へ向けたペット本人の台詞だけを使う。
        // ペット名を三人称で呼ぶ文はナレーションに聞こえるため除外する。
        .where((text) => text.contains('{owner}') && !text.contains('{pet}'))
        .map(
          (text) => _normalizeDirectVoice(text)
              .replaceAll('{owner}', ownerName.isEmpty ? '飼い主さん' : ownerName)
              .trim(),
        )
        .where((text) => text.isNotEmpty)
        .toSet()
        .toList();
    comments.shuffle(Random.secure());
    return comments;
  }

  String _normalizeDirectVoice(String text) {
    return text
        .replaceAll('{owner}、君の', '{owner}の')
        .replaceAll('{owner}、きみの', '{owner}の')
        .replaceAll('{owner}、君', '{owner}、')
        .replaceAll('{owner}、きみ', '{owner}、')
        .replaceAll('君の', '{owner}の')
        .replaceAll('きみの', '{owner}の')
        .replaceAll('君', '{owner}')
        .replaceAll('きみ', '{owner}')
        .replaceAll(RegExp(r'\{owner\}([、,])\s*\{owner\}'), '{owner}\$1');
  }
}
