import 'package:flutter/material.dart';

class CommentBubble extends StatelessWidget {
  const CommentBubble({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: ShapeDecoration(
          color: cs.onPrimary,
          shape: _BubbleBorder(color: cs.primary),
          shadows: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 20, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _BubbleBorder extends ShapeBorder {
  _BubbleBorder({required this.color});
  final Color color;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    // 下向きのとんがり
    const tailW = 20.0;
    const tailH = 12.0;
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height - tailH), const Radius.circular(16));
    final p = Path()..addRRect(r);
    final cx = rect.left + rect.width / 2;
    p.moveTo(cx - tailW/2, rect.bottom - tailH);
    p.lineTo(cx, rect.bottom);
    p.lineTo(cx + tailW/2, rect.bottom - tailH);
    p.close();
    return p;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()..color = Colors.white;
    canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
    // 外枠少し
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withOpacity(0.6);
    canvas.drawPath(getOuterPath(rect, textDirection: textDirection), stroke);
  }

  @override
  ShapeBorder scale(double t) => this;
}
