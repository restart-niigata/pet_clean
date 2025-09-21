import 'package:flutter/material.dart';
import 'personality_select_page.dart';

class PetSelectionPage extends StatelessWidget {
  final String ownerName;
  final String petName;

  const PetSelectionPage({
    super.key,
    required this.ownerName,
    required this.petName,
  });

  static final _pets = <Map<String, String>>[
    {'label': '犬', 'asset': 'assets/images/dog.png'},
    {'label': '猫', 'asset': 'assets/images/cat.png'},
    {'label': 'ウサギ', 'asset': 'assets/images/rabbit.png'},
    {'label': 'ハムスター', 'asset': 'assets/images/hamster.png'},
    {'label': '鳥', 'asset': 'assets/images/bird.png'},
    {'label': 'フェレット', 'asset': 'assets/images/ferret.png'},
    {'label': 'フクロモモンガ', 'asset': 'assets/images/sugar_glider.png'},
    {'label': 'ウーパールーパー', 'asset': 'assets/images/axolotl.png'},
    {'label': '馬', 'asset': 'assets/images/horse.png'},
    {'label': '象', 'asset': 'assets/images/other_elephant.png'},
    {'label': 'パンダ', 'asset': 'assets/images/other_panda.png'},
    {'label': '牛', 'asset': 'assets/images/other_cow.png'},
    {'label': '猿', 'asset': 'assets/images/other_monkey.png'},
  ];

  void _goNext(BuildContext context, String species) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PersonalitySelectPage(
        ownerName: ownerName,
        petName: petName,
        species: species,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ペット選択')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pets.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .8),
        itemBuilder: (ctx, i) {
          final p = _pets[i];
          return InkWell(
            onTap: () => _goNext(context, p['label']!),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      p['asset']!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(p['label']!, style: t.textTheme.labelLarge),
              ],
            ),
          );
        },
      ),
    );
  }
}
