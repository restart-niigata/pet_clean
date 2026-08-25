import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
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
  final documents = await getApplicationDocumentsDirectory();
  await Directory(documents.path).create(recursive: true);
  final savedPath = '${documents.path}/$fileName';
  await File(savedPath).writeAsBytes(bytes);

  final temporary = await getTemporaryDirectory();
  final sharePath = '${temporary.path}/$fileName';
  await File(sharePath).writeAsBytes(bytes);

  return PreparedShareFile(
    file: XFile(sharePath, mimeType: 'image/jpeg'),
    savedName: fileName,
    persisted: true,
  );
}
