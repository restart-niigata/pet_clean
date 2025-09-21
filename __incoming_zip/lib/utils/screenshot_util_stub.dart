import 'package:flutter/widgets.dart';

class ScreenshotUtil {
  static Future<void> captureAndSave({
    required GlobalKey previewContainerKey,
    required String fileName,
  }) async {
    throw UnsupportedError('Screenshot saving is only supported on web.');
  }
}
