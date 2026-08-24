import 'dart:convert';
import 'dart:io';

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
  });
}
