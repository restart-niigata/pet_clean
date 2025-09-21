// lib/widgets/personality_dropdown.dart
import 'package:flutter/material.dart';
import '../models/personality.dart';

class PersonalityDropdown extends StatelessWidget {
  final Personality? value;
  final ValueChanged<Personality?> onChanged;
  final bool requiredField;
  final String label;

  const PersonalityDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.requiredField = true,
    this.label = '性格',
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Personality>(
      value: value,
      items: Personality.values
          .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
          .toList(),
      onChanged: onChanged,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '性格',
        border: OutlineInputBorder(),
      ),
      validator: !requiredField ? null : (v) => v == null ? '性格を選択してください' : null,
    );
  }
}
