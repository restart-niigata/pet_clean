import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

class ScreenshotUtil {
  /// [boundaryKey] で囲ったウィジェットをPNGにして一時ファイルへ保存し、その [File] を返す
  static Future<File?> captureToTempFile({
    required GlobalKey boundaryKey,
    String fileName = 'pet_clean_share.png',
    double pixelRatio = 3.0,
  }) async {
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final bytes = byteData.buffer.asUint8List();
    final file = File('${Directory.systemTemp.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
