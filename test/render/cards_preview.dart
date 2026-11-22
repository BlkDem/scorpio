import 'package:flutter/material.dart';
import 'package:scorpion/ui/art/card_painter.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Preview()));

class Preview extends StatelessWidget {
  const Preview({super.key});
  @override
  Widget build(BuildContext context) {
    final cards = [
      0,
      9,
      10,
      11,
      12,
      13 + 6,
      13 + 10,
      13 + 11,
      13 + 12,
      26,
      26 + 7,
      26 + 10,
      26 + 11,
      26 + 12,
      39 + 4,
      39 + 10,
      39 + 11,
      39 + 12,
    ];
    return Scaffold(
      backgroundColor: const Color(0xFF0E5A30),
      body: SafeArea(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in cards) CustomPaint(size: const Size(76, 106.4), painter: _P(c)),
            for (var b = 0; b < 4; b++) CustomPaint(size: const Size(76, 106.4), painter: _P(-1 - b)),
            CustomPaint(size: const Size(150, 210), painter: _P(12)),
            CustomPaint(size: const Size(150, 210), painter: _P(-1)),
          ],
        ),
      ),
    );
  }
}

class _P extends CustomPainter {
  final int card;
  _P(this.card);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius((Offset.zero & size).shift(const Offset(0, 1.5)), const Radius.circular(6)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    if (card >= 0) {
      CardPainterKit.paintFace(canvas, size, card);
    } else {
      CardPainterKit.paintBack(canvas, size, BackDesign.all[-card - 1]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
