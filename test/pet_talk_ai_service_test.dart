import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pet_clean/services/pet_talk_ai_service.dart';
import 'package:test/test.dart';

void main() {
  group('PetTalkAiService', () {
    test('returns null without an endpoint', () async {
      final service = PetTalkAiService(endpoint: '');

      expect(service.isConfigured, isFalse);
      expect(
        await service.generateComment(
          species: '犬',
          personality: '元気',
          dialect: '標準語',
        ),
        isNull,
      );
    });

    test('rejects non-local plain HTTP endpoints', () async {
      final service = PetTalkAiService(
        endpoint: 'http://example.com/comment',
      );

      expect(
        await service.generateComment(
          species: '犬',
          personality: '元気',
          dialect: '標準語',
        ),
        isNull,
      );
    });

    test('posts pet traits without names and sanitizes the response', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final requestHandled = () async {
        final request = await server.first;
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;

        expect(request.method, 'POST');
        expect(body['species'], '猫');
        expect(body['personality'], '甘えん坊');
        expect(body['dialect'], '関西弁');
        expect(body, isNot(contains('ownerName')));
        expect(body, isNot(contains('petName')));

        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'comment': '  {pet}、\n遊ぼな！  '}));
        await request.response.close();
      }();

      final service = PetTalkAiService(
        endpoint: 'http://127.0.0.1:${server.port}/comment',
      );
      final result = await service.generateComment(
        species: '猫',
        personality: '甘えん坊',
        dialect: '関西弁',
      );

      await requestHandled;
      expect(result, '{pet}、 遊ぼな！');
    });

    test('posts a camera frame and parses pet vision results', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final requestHandled = () async {
        final request = await server.first;
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;

        expect(request.method, 'POST');
        expect(body['imageBase64'], base64Encode([1, 2, 3]));
        expect(body['species'], '犬');
        expect(body['personality'], '元気');
        expect(body['dialect'], '標準語');
        expect(body['clientId'], '123e4567-e89b-42d3-a456-426614174000');

        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'petDetected': true,
          'species': '犬',
          'confidence': 0.91,
          'observedState': '伏せてこちらを見ている',
          'comment': 'お散歩まだかな？',
          'comments': ['お散歩まだかな？', '一緒に遊ぼう！', '今日は何する？'],
        }));
        await request.response.close();
      }();

      final service = PetTalkAiService(
        endpoint: 'http://127.0.0.1:${server.port}/v1/analyze',
      );
      final result = await service.analyzeImage(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        species: '犬',
        personality: '元気',
        dialect: '標準語',
        clientId: '123e4567-e89b-42d3-a456-426614174000',
      );

      await requestHandled;
      expect(result, isNotNull);
      expect(result!.petDetected, isTrue);
      expect(result.species, '犬');
      expect(result.confidence, 0.91);
      expect(result.observedState, '伏せてこちらを見ている');
      expect(result.comment, 'お散歩まだかな？');
      expect(result.comments, ['お散歩まだかな？', '一緒に遊ぼう！', '今日は何する？']);
    });

    test('reports a detected species that differs from the selection',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final requestHandled = () async {
        final request = await server.first;
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'petDetected': false,
          'species': '',
          'detectedSpecies': '犬',
          'confidence': 0.98,
          'observedState': '',
          'comment': '',
          'comments': <String>[],
        }));
        await request.response.close();
      }();

      final service = PetTalkAiService(
        endpoint: 'http://127.0.0.1:${server.port}/v1/analyze',
      );
      final result = await service.analyzeImage(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        species: 'フクロモモンガ',
        personality: '元気',
        dialect: '標準語',
        clientId: '123e4567-e89b-42d3-a456-426614174000',
      );

      await requestHandled;
      expect(result, isNotNull);
      expect(result!.petDetected, isFalse);
      expect(result.detectedSpecies, '犬');
    });

    test('reports rate limiting separately from connection failures', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final handled = () async {
        final request = await server.first;
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.tooManyRequests;
        await request.response.close();
      }();
      final service = PetTalkAiService(
        endpoint: 'http://127.0.0.1:${server.port}/v1/analyze',
      );

      final result = await service.analyzeImage(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        species: 'フクロモモンガ',
        personality: '元気',
        dialect: '標準語',
        clientId: '123e4567-e89b-42d3-a456-426614174000',
      );

      await handled;
      expect(result, isNull);
      expect(service.lastVisionFailure, PetVisionFailure.rateLimited);
    });

    test('rewrites collected comments without changing their count', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final handled = () async {
        final request = await server.first;
        expect(request.uri.path, '/v1/rewrite-comments');
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['personality'], '甘えん坊');
        expect(body['dialect'], '関西弁');
        expect(body['observedState'], '横になって目を閉じている');
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'comments': ['そばにおってや', 'なでてほしいねん'],
        }));
        await request.response.close();
      }();
      final service = PetTalkAiService(
        endpoint: 'http://127.0.0.1:${server.port}/v1/analyze',
      );
      final result = await service.rewriteComments(
        comments: ['そばにいてね', 'なでてほしいな'],
        species: '犬',
        personality: '甘えん坊',
        dialect: '関西弁',
        observedState: '横になって目を閉じている',
        clientId: '123e4567-e89b-42d3-a456-426614174000',
      );
      await handled;
      expect(result, ['そばにおってや', 'なでてほしいねん']);
    });

    test('sends recognized text and parses a personality-aware reply',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final handled = () async {
        final request = await server.first;
        expect(request.uri.path, '/v1/reply');
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['message'], '今日は何したい？');
        expect(body['personality'], 'やんちゃ');
        expect(body['observedState'], '伏せて目を閉じている');
        expect(body['history'], [
          {'role': 'owner', 'content': '昨日はボールで遊んだね'},
          {'role': 'pet', 'content': '今日もやりたいわ！'},
        ]);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'reply': '追いかけっこしよや！'}));
        await request.response.close();
      }();
      final service = PetTalkAiService(
        endpoint: 'http://127.0.0.1:${server.port}/v1/analyze',
      );
      final result = await service.generateReply(
        message: '今日は何したい？',
        species: '犬',
        personality: 'やんちゃ',
        dialect: '関西弁',
        observedState: '伏せて目を閉じている',
        clientId: '123e4567-e89b-42d3-a456-426614174000',
        history: const [
          {'role': 'owner', 'content': '昨日はボールで遊んだね'},
          {'role': 'pet', 'content': '今日もやりたいわ！'},
        ],
      );
      await handled;
      expect(result, '追いかけっこしよや！');
    });
  });
}
