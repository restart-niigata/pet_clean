import 'dart:async';
import 'package:flutter/material.dart';

/// 開始ボタン直後に 1 秒だけ表示するオーバーレイ
class TransitionOverlay extends StatefulWidget {
  const TransitionOverlay({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<TransitionOverlay> createState() => _TransitionOverlayState();
}

class _TransitionOverlayState extends State<TransitionOverlay> {
  @override
  void initState() {
    super.initState();
    // 900ms にして少しだけ軽く感じさせる
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Image.asset(
          'assets/images/top_pet.png',
          width: MediaQuery.of(context).size.width * 0.45,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
