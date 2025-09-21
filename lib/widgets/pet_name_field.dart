import 'package:flutter/material.dart';

class PetNameField extends StatelessWidget {
  const PetNameField({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: const InputDecoration(
        labelText: 'ペット名',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: (v) {
        if ((v ?? '').trim().isEmpty) return 'ペット名を入力してください';
        return null;
      },
      textInputAction: TextInputAction.next,
    );
  }
}
