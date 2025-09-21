import 'package:flutter/material.dart';

class OwnerNameField extends StatelessWidget {
  const OwnerNameField({
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
        labelText: '飼い主名',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: (v) {
        if ((v ?? '').trim().isEmpty) return '飼い主名を入力してください';
        return null;
      },
      textInputAction: TextInputAction.next,
    );
  }
}
