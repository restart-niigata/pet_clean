// lib/pages/pet_type_select_page.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart' show CameraDescription; // main.dart の引数型に合わせる
import '../data/pet_assets.dart';

class PetTypeSelectPage extends StatelessWidget {
  const PetTypeSelectPage({super.key, this.cameras});

  // main.dart から渡されるが、このページでは使わない（互換用）
  final List<CameraDescription>? cameras;

  @override
  Widget build(BuildContext context) {
    final items = PetAssets.species;

    return Scaffold(
      appBar: AppBar(title: const Text('ペットの種類を選択')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemBuilder: (context, index) {
          final sp = items[index];
          final img = PetAssets.imageOf(sp);
          return InkWell(
            onTap: () => Navigator.pop(context, sp),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        // ファイル欠如時も×を出さずにフォールバック
                        return Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.pets, size: 36),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sp,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
