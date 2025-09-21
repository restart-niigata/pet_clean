import 'package:flutter/material.dart';

class ResultPage extends StatelessWidget {
  final String name;
  final String personality;
  final String mood;
  final String comment;

  const ResultPage({
    super.key,
    required this.name,
    required this.personality,
    required this.mood,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('会話結果')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🐾 $name のプロフィール',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('性格: $personality'),
            Text('気分: $mood'),
            const Divider(height: 32),
            const Text(
              '🗨️ ひとこと',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              '「$comment」',
              style: const TextStyle(fontSize: 18),
            ),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('はじめに戻る'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
