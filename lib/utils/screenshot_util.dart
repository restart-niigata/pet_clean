// lib/utils/screenshot_util.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';      // ← GlobalKey / BuildContext
import 'package:flutter/rendering.dart';     // ← RenderRepaintBoundary

class ScreenshotUtil {
  /// RepaintBoundary で囲った領域を PNG にして一時ファイルへ保存して返す。
  /// 追加パッケージ不要。ギャラリー保存はせず共有用に temp へ保存のみ。
  static Future<File?> captureToTempFile({
    required GlobalKey boundaryKey,
    String fileName = 'pet_clean_share.png',
    double pixelRatio = 3.0,
  }) async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final Uint8List bytes = byteData.buffer.asUint8List();
    final file = File('${Directory.systemTemp.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
