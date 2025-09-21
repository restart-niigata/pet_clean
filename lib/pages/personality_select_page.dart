// lib/pages/personality_select_page.dart
import 'package:flutter/material.dart';

class PersonalitySelectPage extends StatelessWidget {
  final String current;
  const PersonalitySelectPage({super.key, required this.current});

  static const List<String> _list = [
    '元気','おっとり','クール','甘えん坊','臆病','おしゃべり','やんちゃ'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('性格を選択')),
      body: ListView.separated(
        itemCount: _list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final v = _list[i];
          return ListTile(
            title: Text(v),
            trailing: v == current ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop(v),
          );
        },
      ),
    );
  }
}
