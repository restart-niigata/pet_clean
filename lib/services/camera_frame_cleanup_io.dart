import 'dart:io';

Future<void> cleanupCameraFrame(String path) async {
  if (path.isEmpty) return;
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
