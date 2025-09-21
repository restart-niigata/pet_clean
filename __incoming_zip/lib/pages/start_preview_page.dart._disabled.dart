// lib/pages/start_preview_page.dart
import 'package:flutter/material.dart';
import '../models/pet_type.dart';

class StartPreviewPage extends StatelessWidget {
  const StartPreviewPage({
    super.key,
    required this.ownerName,
    required this.petName,
    required this.petType,
    required this.personalityLabel,
  });

  final String ownerName;
  final String petName;
  final PetType petType;
  final String personalityLabel;

  @override
  Widget build(BuildContext context) {
    final img = _assetFor(petType);

    return Scaffold(
      appBar: AppBar(title: const Text('確認')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              img,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image_not_supported, size: 80),
            ),
          ),
          const SizedBox(height: 16),
          _tile('飼い主名', ownerName),
          const Divider(),
          _tile('ペット名', petName),
          const Divider(),
          _tile('種類', petType.label),
          const Divider(),
          _tile('性格', personalityLabel),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              // ここで次の画面に進めたい場合は適宜差し替え。
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ここから次の処理へ進めます')),
              );
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _tile(String title, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(value, style: const TextStyle(fontSize: 16)),
    );
  }
}

String _assetFor(PetType t) {
  switch (t) {
    case PetType.dog:
      return 'assets/images/dog.png';
    case PetType.cat:
      return 'assets/images/cat.png';
    case PetType.rabbit:
      return 'assets/images/rabbit.png';
    case PetType.hamster:
      return 'assets/images/hamster.png';
    case PetType.bird:
      return 'assets/images/bird.png';
    case PetType.sugarGlider:
      return 'assets/images/sugar_glider.png';
    case PetType.ferret:
      return 'assets/images/ferret.png';
    case PetType.axolotl:
      return 'assets/images/axolotl.png';
    case PetType.horse:
      return 'assets/images/horse.png';
    case PetType.elephant:
      return 'assets/images/other_elephant.png';
    case PetType.panda:
      return 'assets/images/other_panda.png';
    case PetType.cow:
      return 'assets/images/other_cow.png';
    case PetType.monkey:
      return 'assets/images/other_monkey.png';
  }
}
