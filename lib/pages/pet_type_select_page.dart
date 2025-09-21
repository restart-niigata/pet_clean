// lib/pages/pet_type_select_page.dart
import 'package:flutter/material.dart';

class PetTypeSelectPage extends StatelessWidget {
  final String current;
  const PetTypeSelectPage({super.key, required this.current});

  static const Map<String, String> _speciesAssets = {
    '犬': 'assets/images/dog.png',
    '猫': 'assets/images/cat.png',
    'ウサギ': 'assets/images/rabbit.png',
    'ハムスター': 'assets/images/hamster.png',
    '鳥': 'assets/images/bird.png',
    'フクロモモンガ': 'assets/images/sugar_glider.png',
    'フェレット': 'assets/images/ferret.png',
    'ウーパールーパー': 'assets/images/axolotl.png',
    '馬': 'assets/images/horse.png',
    '象': 'assets/images/other_elephant.png',
    'パンダ': 'assets/images/other_panda.png',
    '牛': 'assets/images/other_cow.png',
    '猿': 'assets/images/other_monkey.png',
  };

  @override
  Widget build(BuildContext context) {
    final items = _speciesAssets.entries.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('ペットの種類を選択')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .8),
        itemBuilder: (_, i) {
          final label = items[i].key;
          final asset = items[i].value;
          final selected = label == current;
          return InkWell(
            onTap: () => Navigator.of(context).pop(label),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(asset, fit: BoxFit.contain),
                        ),
                      ),
                      if (selected)
                        const Positioned(
                          right: 6, top: 6,
                          child: CircleAvatar(radius: 12, child: Icon(Icons.check, size: 16)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(label),
              ],
            ),
          );
        },
      ),
    );
  }
}
