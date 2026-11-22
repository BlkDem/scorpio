import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../state/settings.dart';

/// Сукно игрового стола: градиент освещения, ворс, виньетка.
class FeltBackground extends StatelessWidget {
  final TableDesign design;
  const FeltBackground({super.key, required this.design});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _FeltPainter(design), isComplex: true, child: const SizedBox.expand()),
    );
  }
}

class _FeltPainter extends CustomPainter {
  final TableDesign d;
  _FeltPainter(this.d);

  static final Map<int, ui.Image> _tiles = {};

  static ui.Image _tile(TableDesign d) {
    final key = d.fiber.toARGB32();
    return _tiles[key] ??= _makeTile(d.fiber);
  }

  static ui.Image _makeTile(Color fiber) {
    const size = 256.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final rnd = math.Random(11);
    // Зерно: светлые и тёмные точки.
    for (var pass = 0; pass < 4; pass++) {
      final n = 9000;
      final pts = Float32List(n * 2);
      for (var i = 0; i < n; i++) {
        pts[i * 2] = rnd.nextDouble() * size;
        pts[i * 2 + 1] = rnd.nextDouble() * size;
      }
      final light = pass.isEven;
      c.drawRawPoints(
        ui.PointMode.points,
        pts,
        Paint()
          ..color = light ? fiber.withValues(alpha: 0.07 + pass * 0.01) : const Color(0x1A000000)
          ..strokeWidth = 1.0 + (pass == 3 ? 0.6 : 0),
      );
    }
    // Ворсинки.
    final fp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 700; i++) {
      final x = rnd.nextDouble() * size;
      final y = rnd.nextDouble() * size;
      final a = rnd.nextDouble() * math.pi * 2;
      final len = 2 + rnd.nextDouble() * 5;
      fp.color = rnd.nextBool() ? fiber.withValues(alpha: 0.09) : const Color(0x14000000);
      final p = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(
          x + math.cos(a + 0.6) * len * 0.6,
          y + math.sin(a + 0.6) * len * 0.6,
          x + math.cos(a) * len,
          y + math.sin(a) * len,
        );
      // Рисуем с переносом через край, чтобы плитка была бесшовной.
      for (final dx in const [-size, 0.0, size]) {
        for (final dy in const [-size, 0.0, size]) {
          c.save();
          c.translate(dx, dy);
          c.drawPath(p, fp);
          c.restore();
        }
      }
    }
    final pic = rec.endRecording();
    return pic.toImageSync(size.toInt(), size.toInt());
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Свет лампы над столом.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.32),
          size.longestSide * 0.85,
          [Color.lerp(d.center, const Color(0xFFFFFFFF), 0.06)!, d.center, d.edge],
          const [0, 0.45, 1],
        ),
    );
    // Фактура сукна.
    final tile = _tile(d);
    canvas.drawRect(
      rect,
      Paint()..shader = ui.ImageShader(tile, TileMode.repeated, TileMode.repeated, Matrix4.identity().storage),
    );
    // Мягкая виньетка.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          size.longestSide * 0.75,
          const [Color(0x00000000), Color(0x00000000), Color(0x66000000)],
          const [0, 0.55, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _FeltPainter old) => old.d != d;
}
