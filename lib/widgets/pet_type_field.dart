// lib/widgets/pet_type_field.dart
import 'package:flutter/material.dart';
import 'package:pet_clean/models/pet_type.dart';

class PetTypeField extends StatelessWidget {
  const PetTypeField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PetType value;
  final ValueChanged<PetType> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = PetTypeX.orderedValues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final t in items)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: Image.asset(t.iconPath, width: 32, height: 32),
            title: Text(t.label),
            trailing: Radio<PetType>(
              value: t,
              groupValue: value,
              onChanged: (v) => v != null ? onChanged(v) : null,
            ),
            onTap: () => onChanged(t),
          ),
      ],
    );
  }
}
