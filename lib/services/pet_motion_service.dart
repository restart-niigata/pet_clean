import 'dart:typed_data';

import 'package:camera/camera.dart';

/// カメラ画像を外部へ送らず、低解像度の明るさ差だけで大きな動きを検出する。
class PetMotionService {
  List<int>? _previousSignature;
  int _consecutiveChanges = 0;

  void reset() {
    _previousSignature = null;
    _consecutiveChanges = 0;
  }

  bool detect(CameraImage image) {
    if (image.planes.isEmpty) return false;
    final plane = image.planes.first;
    return detectPlane(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      bytesPerPixel: plane.bytesPerPixel ?? 1,
    );
  }

  bool detectPlane({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
    required int bytesPerPixel,
  }) {
    if (bytes.isEmpty || width < 2 || height < 2 || bytesPerRow < 1) {
      return false;
    }
    final signature = <int>[];
    const columns = 12;
    const rows = 16;
    for (var row = 1; row <= rows; row++) {
      final y = ((height - 1) * row / (rows + 1)).round();
      for (var column = 1; column <= columns; column++) {
        final x = ((width - 1) * column / (columns + 1)).round();
        final offset = y * bytesPerRow + x * bytesPerPixel;
        if (offset < 0 || offset >= bytes.length) continue;
        if (bytesPerPixel >= 3 && offset + 2 < bytes.length) {
          final blue = bytes[offset];
          final green = bytes[offset + 1];
          final red = bytes[offset + 2];
          signature.add((red * 3 + green * 6 + blue) ~/ 10);
        } else {
          signature.add(bytes[offset]);
        }
      }
    }
    if (signature.isEmpty) return false;

    final previous = _previousSignature;
    _previousSignature = signature;
    if (previous == null || previous.length != signature.length) return false;

    var totalDifference = 0;
    for (var index = 0; index < signature.length; index++) {
      totalDifference += (signature[index] - previous[index]).abs();
    }
    final averageDifference = totalDifference / signature.length;
    if (averageDifference >= 18) {
      _consecutiveChanges++;
    } else {
      _consecutiveChanges = 0;
    }
    if (_consecutiveChanges < 2) return false;
    _consecutiveChanges = 0;
    return true;
  }
}
