import 'dart:typed_data';
import 'dart:ui' as ui;

/// AIの定期観察用画像を小さなPNGへ変換し、画像推論の消費量を抑える。
Future<Uint8List> resizeImageForObservation(
  Uint8List source, {
  int maxWidth = 336,
}) async {
  final codec = await ui.instantiateImageCodec(source, targetWidth: maxWidth);
  try {
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return source;
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    codec.dispose();
  }
}
