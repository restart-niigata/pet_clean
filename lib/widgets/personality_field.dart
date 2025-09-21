// lib/widgets/pet_type_field.dart
import 'package:flutter/material.dart';
import 'package:pet_clean/models/pet_type.dart';

class PetTypeField extends StatelessWidget {
  final PetType value;
  final ValueChanged<PetType> onChanged;

  const PetTypeField({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = PetTypeX.orderedValues;
    return DropdownButtonFormField<PetType>(
      value: value,
      decoration: const InputDecoration(labelText: 'ペットの種類'),
      items: items
          .map(
            (t) => DropdownMenuItem(
              value: t,
              child: Row(
                children: [
                  // アセットが無くても落ちないようにフォールバック
                  Image.asset(
                    t.iconPath,
                    width: 24,
                    height: 24,
                    errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(t.label),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
