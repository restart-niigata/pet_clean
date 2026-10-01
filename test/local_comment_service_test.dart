import 'package:pet_clean/services/local_comment_service.dart';
import 'package:test/test.dart';

void main() {
  test('loads only the selected species and personality', () async {
    final service = LocalCommentService(
      assetLoader: () async => '''
        {
          "犬_元気": [
            {"species":"犬","personality":"元気","text":"{pet}は遊びたいな"},
            {"species":"犬","personality":"元気","text":"{owner}が大好きだよ"}
          ],
          "犬_クール": [
            {"species":"犬","personality":"クール","text":"静かに過ごしたいな"}
          ]
        }
      ''',
    );
    final comments = await service.load(
      species: '犬',
      personality: '元気',
      ownerName: '飼い主',
      petName: 'ポチ',
    );

    expect(comments, isNotEmpty);
    expect(comments, everyElement(isNot(contains('{owner}'))));
    expect(comments, everyElement(isNot(contains('{pet}'))));
    expect(comments, hasLength(1));
    expect(comments.single, '飼い主が大好きだよ');
    expect(comments, isNot(contains('静かに過ごしたいな')));
  });

  test('keeps only lines spoken directly by the pet to the owner', () async {
    final service = LocalCommentService(
      assetLoader: () async => '''
        {
          "フェレット_クール": [
            {"species":"フェレット","personality":"クール","text":"{pet}は静かに見ているよ"},
            {"species":"フェレット","personality":"クール","text":"{owner}、君の声は落ち着くな"},
            {"species":"フェレット","personality":"クール","text":"静かな時間が好きだよ"}
          ]
        }
      ''',
    );

    final comments = await service.load(
      species: 'フェレット',
      personality: 'クール',
      ownerName: 'みき',
      petName: 'うなぎ',
    );

    expect(comments, ['みきの声は落ち着くな']);
    expect(comments, everyElement(isNot(contains('うなぎは'))));
  });
}
