// lib/pages/dialect_select_page.dart
import 'package:flutter/material.dart';

class DialectSelectPage extends StatelessWidget {
  final String current;
  const DialectSelectPage({super.key, required this.current});

  // 仕様書固定リスト
  static const List<String> _dialects = [
    '標準語',
    '関西弁',
    '新潟弁',
    '福岡弁',
    '広島弁',
    '福島弁',
    '秋田弁',
    '名古屋弁',
    '金沢弁',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('方言を選択')),
      body: ListView.separated(
        itemCount: _dialects.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final value = _dialects[i];
          final selected = value == current;
          return ListTile(
            title: Text(value),
            trailing: selected ? const Icon(Icons.check, color: Colors.blue) : null,
            onTap: () => Navigator.of(context).pop<String>(value),
          );
        },
      ),
    );
  }
}
