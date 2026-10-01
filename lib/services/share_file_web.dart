import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

class PreparedShareFile {
  const PreparedShareFile({
    required this.file,
    required this.savedName,
    required this.persisted,
  });

  final XFile file;
  final String savedName;
  final bool persisted;
}

Future<PreparedShareFile> prepareShareFile(
  Uint8List bytes,
  String fileName,
) async {
  return PreparedShareFile(
    file: XFile.fromData(bytes, mimeType: 'image/jpeg', name: fileName),
    savedName: fileName,
    persisted: false,
  );
}
