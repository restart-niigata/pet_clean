import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class PetVisionResult {
  const PetVisionResult({
    required this.petDetected,
    required this.species,
    required this.confidence,
    required this.comment,
    this.observedState = '',
    this.detectedSpecies = '',
    this.comments = const [],
  });

  final bool petDetected;
  final String species;
  final double confidence;
  final String comment;
  final String observedState;
  final String detectedSpecies;
  final List<String> comments;
}

enum PetVisionFailure {
  none,
  notConfigured,
  retryTooSoon,
  rateLimited,
  timeout,
  unavailable,
  invalidResponse,
}

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
    this.visionTimeout = const Duration(seconds: 30),
    this.visionRetryDelay = Duration.zero,
    this.visionMinimumRequestInterval = Duration.zero,
  })  : endpoint =
            endpoint ?? const String.fromEnvironment('PET_TALK_AI_ENDPOINT'),
        _httpClientFactory = httpClientFactory ?? http.Client.new;

  final String endpoint;
  final Duration timeout;
  final Duration retryDelay;
  final Duration minimumRequestInterval;
  final Duration visionTimeout;
  final Duration visionRetryDelay;
  final Duration visionMinimumRequestInterval;
  final http.Client Function() _httpClientFactory;

  DateTime? _retryAfter;
  DateTime? _lastRequestAt;
  DateTime? _visionRetryAfter;
  DateTime? _lastVisionRequestAt;
  PetVisionFailure lastVisionFailure = PetVisionFailure.none;

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

  Future<PetVisionResult?> analyzeImage({
    required Uint8List imageBytes,
    required String species,
    required String personality,
    required String dialect,
    required String clientId,
  }) async {
    if (!isConfigured) {
      lastVisionFailure = PetVisionFailure.notConfigured;
      return null;
    }
    if (!_canTryVisionNow()) {
      lastVisionFailure = PetVisionFailure.retryTooSoon;
      return null;
    }
    if (imageBytes.isEmpty) {
      lastVisionFailure = PetVisionFailure.invalidResponse;
      return null;
    }

    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null || !_isAllowedEndpoint(uri)) {
      lastVisionFailure = PetVisionFailure.unavailable;
      _pauseVisionRetries();
      return null;
    }

    _lastVisionRequestAt = DateTime.now();
    final client = _httpClientFactory();
    try {
      final response = await client
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              'accept': 'application/json',
              'x-client-id': clientId,
            },
            body: jsonEncode(<String, String>{
              'imageBase64': base64Encode(imageBytes),
              'species': species,
              'personality': personality,
              'dialect': dialect,
              'clientId': clientId,
            }),
          )
          .timeout(visionTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        lastVisionFailure = response.statusCode == 429
            ? PetVisionFailure.rateLimited
            : PetVisionFailure.unavailable;
        _pauseVisionRetries();
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['petDetected'] is! bool) {
        lastVisionFailure = PetVisionFailure.invalidResponse;
        _pauseVisionRetries();
        return null;
      }

      final detected = decoded['petDetected'] as bool;
      final rawConfidence = decoded['confidence'];
      final confidence = rawConfidence is num
          ? rawConfidence.toDouble().clamp(0, 1).toDouble()
          : 0.0;
      final detectedSpecies = _sanitize(decoded['species']?.toString() ?? '');
      final mismatchedSpecies =
          _sanitize(decoded['detectedSpecies']?.toString() ?? '');
      final observedState =
          _sanitize(decoded['observedState']?.toString() ?? '');
      final comment = _sanitize(decoded['comment']?.toString() ?? '');
      final rawComments = decoded['comments'];
      final comments = rawComments is List
          ? rawComments
              .whereType<String>()
              .map(_sanitize)
              .where((value) => value.isNotEmpty)
              .toSet()
              .take(3)
              .toList()
          : <String>[];
      if (comment.isNotEmpty && !comments.contains(comment)) {
        comments.insert(0, comment);
      }

      if (detected &&
          (detectedSpecies.isEmpty ||
              observedState.isEmpty ||
              comments.isEmpty)) {
        lastVisionFailure = PetVisionFailure.invalidResponse;
        _pauseVisionRetries();
        return null;
      }

      _visionRetryAfter = null;
      lastVisionFailure = PetVisionFailure.none;
      return PetVisionResult(
        petDetected: detected,
        species: detected ? detectedSpecies : '',
        confidence: confidence,
        comment: detected ? comments.first : '',
        observedState: detected ? observedState : '',
        detectedSpecies: detected ? detectedSpecies : mismatchedSpecies,
        comments: detected ? comments : const [],
      );
    } on TimeoutException {
      lastVisionFailure = PetVisionFailure.timeout;
      _pauseVisionRetries();
      return null;
    } on Object {
      lastVisionFailure = PetVisionFailure.unavailable;
      _pauseVisionRetries();
      return null;
    } finally {
      client.close();
    }
  }

  Future<List<String>?> rewriteComments({
    required List<String> comments,
    required String species,
    required String personality,
    required String dialect,
    required String observedState,
    required String clientId,
  }) async {
    if (!isConfigured || comments.isEmpty) return null;
    final uri = _endpointFor('/v1/rewrite-comments');
    if (uri == null || !_isAllowedEndpoint(uri)) return null;
    final client = _httpClientFactory();
    try {
      final response = await client
          .post(
            uri,
            headers: const {
              'content-type': 'application/json',
              'accept': 'application/json',
            },
            body: jsonEncode({
              'comments': comments.take(8).toList(growable: false),
              'species': species,
              'personality': personality,
              'dialect': dialect,
              'observedState': observedState,
              'clientId': clientId,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['comments'] is! List) {
        return null;
      }
      final rewritten = (decoded['comments'] as List)
          .whereType<String>()
          .map(_sanitize)
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      return rewritten.length == comments.take(8).length ? rewritten : null;
    } on Object {
      return null;
    } finally {
      client.close();
    }
  }

  Future<String?> generateReply({
    required String message,
    required String species,
    required String personality,
    required String dialect,
    required String observedState,
    required String clientId,
    List<Map<String, String>> history = const [],
  }) async {
    if (!isConfigured || message.trim().isEmpty) return null;
    final uri = _endpointFor('/v1/reply');
    if (uri == null || !_isAllowedEndpoint(uri)) return null;
    final client = _httpClientFactory();
    try {
      final response = await client
          .post(
            uri,
            headers: const {
              'content-type': 'application/json',
              'accept': 'application/json',
            },
            body: jsonEncode({
              'message': _sanitize(message),
              'species': species,
              'personality': personality,
              'dialect': dialect,
              'observedState': observedState,
              'clientId': clientId,
              'history': history.take(8).toList(growable: false),
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final reply = _sanitize(decoded['reply']?.toString() ?? '');
      return reply.isEmpty ? null : reply;
    } on Object {
      return null;
    } finally {
      client.close();
    }
  }

  Uri? _endpointFor(String path) {
    final configured = Uri.tryParse(endpoint.trim());
    if (configured == null) return null;
    return configured.replace(path: path, query: null, fragment: null);
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

  bool _canTryVisionNow() {
    final lastRequestAt = _lastVisionRequestAt;
    if (lastRequestAt != null &&
        DateTime.now()
            .isBefore(lastRequestAt.add(visionMinimumRequestInterval))) {
      return false;
    }
    final retryAfter = _visionRetryAfter;
    return retryAfter == null || DateTime.now().isAfter(retryAfter);
  }

  void _pauseVisionRetries() {
    _visionRetryAfter = DateTime.now().add(visionRetryDelay);
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
