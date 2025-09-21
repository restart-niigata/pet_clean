import 'package:flutter/material.dart';

class SpeechBubble extends StatelessWidget {
  final String text;
  const SpeechBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: Colors.black87, height: 1.35, fontSize: 22,
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Text(text, style: ts, softWrap: true),
    );
  }
}
