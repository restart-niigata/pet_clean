import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

class PetPresenceService {
  const PetPresenceService();

  static const _channel = MethodChannel('pet_clean/pet_presence');

  Future<bool?> isPresent(CameraImage image, String species) async {
    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'recognizePet',
        <String, dynamic>{
          'bytes': plane.bytes,
          'width': image.width,
          'height': image.height,
          'bytesPerRow': plane.bytesPerRow,
          'species': species,
        },
      );
      return result?['present'] as bool?;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
