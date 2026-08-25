import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// AIコメント用バックエンドとの通信を担当する。
///
/// APIキーをアプリに含めないため、生成AIへ直接接続せず、自前のバックエンドを
/// [endpoint] に指定する。未設定・通信失敗時は `null` を返し、呼び出し側が
/// ローカルコメントへフォールバックできるようにする。
class PetTalkAiService {
  PetTalkAiService({
    String? endpoint,
    http.Client Function()? httpClientFactory,
    this.timeout = const Duration(seconds: 4),
    this.retryDelay = const Duration(minutes: 5),
    this.minimumRequestInterval = const Duration(minutes: 1),
  })  : endpoint =
            endpoint ?? const String.fromEnvironment('PET_TALK_AI_ENDPOINT'),
        _httpClientFactory = httpClientFactory ?? http.Client.new;

  final String endpoint;
  final Duration timeout;
  final Duration retryDelay;
  final Duration minimumRequestInterval;
  final http.Client Function() _httpClientFactory;

  DateTime? _retryAfter;
  DateTime? _lastRequestAt;

  bool get isConfigured => endpoint.trim().isNotEmpty;

  Future<String?> generateComment({
    required String species,
    required String personality,
    required String dialect,
  }) async {
    if (!isConfigured || !_canTryNow()) return null;

    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null || !_isAllowedEndpoint(uri)) {
      _pauseRetries();
      return null;
    }

    _lastRequestAt = DateTime.now();
    final client = _httpClientFactory();
    try {
      final response = await client
          .post(
            uri,
            headers: const {
              'content-type': 'application/json',
              'accept': 'application/json',
            },
            body: jsonEncode(<String, String>{
              'species': species,
              'personality': personality,
              'dialect': dialect,
            }),
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _pauseRetries();
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        _pauseRetries();
        return null;
      }

      final raw = decoded['comment'];
      if (raw is! String) {
        _pauseRetries();
        return null;
      }

      final comment = _sanitize(raw);
      if (comment.isEmpty) {
        _pauseRetries();
        return null;
      }

      _retryAfter = null;
      return comment;
    } on Object {
      _pauseRetries();
      return null;
    } finally {
      client.close();
    }
  }

  bool _canTryNow() {
    final lastRequestAt = _lastRequestAt;
    if (lastRequestAt != null &&
        DateTime.now().isBefore(lastRequestAt.add(minimumRequestInterval))) {
      return false;
    }
    final retryAfter = _retryAfter;
    return retryAfter == null || DateTime.now().isAfter(retryAfter);
  }

  void _pauseRetries() {
    _retryAfter = DateTime.now().add(retryDelay);
  }

  bool _isAllowedEndpoint(Uri uri) {
    if (uri.scheme == 'https' && uri.host.isNotEmpty) return true;
    final isLocalhost = uri.host == 'localhost' || uri.host == '127.0.0.1';
    return uri.scheme == 'http' && isLocalhost;
  }

  String _sanitize(String value) {
    final oneLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.isEmpty) return '';
    final characters = oneLine.runes.toList(growable: false);
    if (characters.length <= 120) return oneLine;
    return '${String.fromCharCodes(characters.take(119))}…';
  }
}
