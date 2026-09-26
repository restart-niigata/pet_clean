import 'dart:typed_data';

import 'package:pet_clean/services/pet_motion_service.dart';
import 'package:test/test.dart';

void main() {
  test('requires consecutive substantial frame changes', () {
    final service = PetMotionService();
    final dark = Uint8List(40 * 40);
    final bright = Uint8List.fromList(List<int>.filled(40 * 40, 220));

    expect(
      service.detectPlane(
        bytes: dark,
        width: 40,
        height: 40,
        bytesPerRow: 40,
        bytesPerPixel: 1,
      ),
      isFalse,
    );
    expect(
      service.detectPlane(
        bytes: bright,
        width: 40,
        height: 40,
        bytesPerRow: 40,
        bytesPerPixel: 1,
      ),
      isFalse,
    );
    expect(
      service.detectPlane(
        bytes: dark,
        width: 40,
        height: 40,
        bytesPerRow: 40,
        bytesPerPixel: 1,
      ),
      isTrue,
    );
  });

  test('ignores unchanged frames', () {
    final service = PetMotionService();
    final frame = Uint8List.fromList(List<int>.filled(40 * 40, 120));
    for (var index = 0; index < 4; index++) {
      expect(
        service.detectPlane(
          bytes: frame,
          width: 40,
          height: 40,
          bytesPerRow: 40,
          bytesPerPixel: 1,
        ),
        isFalse,
      );
    }
  });
}
