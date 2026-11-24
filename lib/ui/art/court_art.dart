import 'dart:math' as math;
import 'dart:ui';

import '../../game/cards.dart';
import 'suits.dart';

/// Рисует фигуру (валет, дама, король) в рамке. Двуглавая композиция:
/// верхняя половина зеркально повторяется внизу.
class CourtArt {
  static void paint(Canvas canvas, Rect frame, int card) {
    final suit = suitOf(card);
    final rank = rankOf(card);
    final stroke = math.max(0.35, frame.width * 0.011);

    // Фон рамки.
    final bg = Paint()
      ..shader = Gradient.linear(
        frame.topCenter,
        frame.bottomCenter,
        const [Color(0xFFFFF7E4), Color(0xFFFBEED2), Color(0xFFFFF7E4)],
        const [0, 0.5, 1],
      );
    canvas.drawRect(frame, bg);

    canvas.save();
    canvas.clipRect(frame);
    final half = Rect.fromLTWH(frame.left, frame.top, frame.width, frame.height / 2);
    _Figure(canvas, half, suit, rank, stroke).draw();
    canvas.save();
    canvas.translate(frame.center.dx, frame.center.dy);
    canvas.rotate(math.pi);
    canvas.translate(-frame.center.dx, -frame.center.dy);
    _Figure(canvas, half, suit, rank, stroke).draw();
    canvas.restore();
    canvas.restore();

    // Диагональный раздел половинок.
    final line = Paint()
      ..color = const Color(0xFF1B1B1B)
      ..strokeWidth = stroke * 0.9
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(frame.left, frame.center.dy + frame.height * 0.035),
      Offset(frame.right, frame.center.dy - frame.height * 0.035),
      line,
    );

    // Рамка: двойная линия.
    final outer = Paint()
      ..color = isRedSuit(suit) ? const Color(0xFF9A1B2A) : const Color(0xFF1E3D8C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.3;
    canvas.drawRect(frame, outer);
    canvas.drawRect(
      frame.deflate(stroke * 2.2),
      Paint()
        ..color = Ink.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.8,
    );
  }

  /// Одна (верхняя) половина фигуры в рамке — для маленьких карт.
  /// [frame] — область половины, пропорции около 1 : 1.23.
  static void paintBust(Canvas canvas, Rect frame, int card) {
    final suit = suitOf(card);
    final rank = rankOf(card);
    final stroke = math.max(0.35, frame.width * 0.014);
    canvas.drawRect(
      frame,
      Paint()
        ..shader = Gradient.linear(frame.topCenter, frame.bottomCenter, const [
          Color(0xFFFFF7E4),
          Color(0xFFFBEED2),
        ]),
    );
    canvas.save();
    canvas.clipRect(frame);
    _Figure(canvas, frame, suit, rank, stroke).draw();
    canvas.restore();
    canvas.drawRect(
      frame,
      Paint()
        ..color = isRedSuit(suit) ? const Color(0xFF9A1B2A) : const Color(0xFF1E3D8C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 1.4,
    );
  }
}

class _Figure {
  final Canvas c;
  final Rect box;
  final int suit;
  final int rank;
  final double sw;

  _Figure(this.c, this.box, this.suit, this.rank, this.sw);

  // Палитра зависит от масти — так все двенадцать фигур различаются.
  Color get primary => const [Ink.blue, Ink.red, Ink.red, Ink.blue][suit];
  Color get secondary => const [Ink.red, Ink.blue, Color(0xFF1F6B45), Ink.red][suit];
  static const yellow = Color(0xFFF0BE45);
  static const ink = Color(0xFF151515);

  Offset p(double x, double y) => Offset(box.left + x * box.width, box.top + y * box.height);

  Path poly(List<List<double>> pts, {bool close = true}) {
    final path = Path()..moveTo(p(pts[0][0], pts[0][1]).dx, p(pts[0][0], pts[0][1]).dy);
    for (var i = 1; i < pts.length; i++) {
      final o = p(pts[i][0], pts[i][1]);
      path.lineTo(o.dx, o.dy);
    }
    if (close) path.close();
    return path;
  }

  Path curve(List<List<double>> pts) {
    // Каждые три точки после первой — кубическая кривая.
    final path = Path();
    final s = p(pts[0][0], pts[0][1]);
    path.moveTo(s.dx, s.dy);
    for (var i = 1; i + 2 < pts.length + 0; i += 3) {
      final a = p(pts[i][0], pts[i][1]);
      final b = p(pts[i + 1][0], pts[i + 1][1]);
      final d = p(pts[i + 2][0], pts[i + 2][1]);
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, d.dx, d.dy);
    }
    path.close();
    return path;
  }

  Rect r(double x, double y, double w, double h) =>
      Rect.fromLTWH(box.left + x * box.width, box.top + y * box.height, w * box.width, h * box.height);

  void fill(Path path, Color color, {bool outline = true, double k = 1}) {
    c.drawPath(path, Paint()..color = color);
    if (outline) {
      c.drawPath(
        path,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw * k
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void line(double x1, double y1, double x2, double y2, {double k = 1, Color color = ink}) {
    c.drawLine(
      p(x1, y1),
      p(x2, y2),
      Paint()
        ..color = color
        ..strokeWidth = sw * k
        ..strokeCap = StrokeCap.round,
    );
  }

  void dot(double x, double y, double rr, Color color) {
    c.drawCircle(p(x, y), rr * box.width, Paint()..color = color);
  }

  void draw() {
    _robe();
    _item();
    _hairBack();
    _face();
    _headwear();
    // Значок масти в углу рамки.
    final pip = r(0.05, 0.05, 0.15, 0.13);
    c.drawPath(SuitPaths.fit(suit, pip), Paint()..color = Ink.suit(suit));
  }

  void _robe() {
    // Плечи и мантия.
    final mantle = curve([
      [0.06, 1.0],
      [0.06, 0.78],
      [0.14, 0.62],
      [0.34, 0.58],
      [0.42, 0.56],
      [0.58, 0.56],
      [0.66, 0.58],
      [0.86, 0.62],
      [0.94, 0.78],
      [0.94, 1.0],
    ]);
    fill(mantle, primary);

    // Центральная вставка с орнаментом.
    final panel = poly([
      [0.36, 0.6],
      [0.64, 0.6],
      [0.7, 1.0],
      [0.3, 1.0],
    ]);
    fill(panel, yellow);
    for (var i = 0; i < 4; i++) {
      final y = 0.66 + i * 0.085;
      final half = 0.15 + i * 0.012;
      line(0.5 - half, y, 0.5 + half, y, k: 0.7);
      dot(0.5, y + 0.04, 0.025, secondary);
    }
    // Боковые полосы.
    final sideL = poly([
      [0.1, 1.0],
      [0.16, 0.72],
      [0.26, 0.64],
      [0.3, 1.0],
    ]);
    final sideR = poly([
      [0.9, 1.0],
      [0.84, 0.72],
      [0.74, 0.64],
      [0.7, 1.0],
    ]);
    fill(sideL, secondary, k: 0.8);
    fill(sideR, secondary, k: 0.8);
    for (var i = 0; i < 3; i++) {
      dot(0.21 - i * 0.012, 0.76 + i * 0.08, 0.018, yellow);
      dot(0.79 + i * 0.012, 0.76 + i * 0.08, 0.018, yellow);
    }

    // Воротник.
    if (rank == 13) {
      // Горностай.
      final collar = curve([
        [0.3, 0.6],
        [0.36, 0.52],
        [0.64, 0.52],
        [0.7, 0.6],
        [0.6, 0.68],
        [0.4, 0.68],
        [0.3, 0.6],
      ]);
      fill(collar, const Color(0xFFFFFDF6));
      for (final x in [0.38, 0.46, 0.54, 0.62]) {
        line(x, 0.58, x, 0.62, k: 1.4);
      }
    } else if (rank == 12) {
      final collar = curve([
        [0.28, 0.6],
        [0.36, 0.5],
        [0.64, 0.5],
        [0.72, 0.6],
        [0.62, 0.64],
        [0.38, 0.64],
        [0.28, 0.6],
      ]);
      fill(collar, secondary);
      // Ожерелье.
      for (var i = 0; i < 7; i++) {
        final t = i / 6;
        final x = 0.38 + t * 0.24;
        final y = 0.6 + math.sin(t * math.pi) * 0.04;
        dot(x, y, 0.016, const Color(0xFFFFFDF6));
      }
    } else {
      final collar = poly([
        [0.34, 0.58],
        [0.5, 0.66],
        [0.66, 0.58],
        [0.6, 0.54],
        [0.4, 0.54],
      ]);
      fill(collar, const Color(0xFFFFFDF6));
      line(0.5, 0.58, 0.5, 0.66, k: 0.7);
    }
  }

  void _item() {
    if (rank == 13) {
      // Меч или скипетр.
      if (suit == kHearts || suit == kSpades) {
        final blade = poly([
          [0.84, 0.04],
          [0.875, 0.1],
          [0.875, 0.86],
          [0.805, 0.86],
          [0.805, 0.1],
        ]);
        fill(blade, const Color(0xFFCBD3DC), k: 0.8);
        line(0.84, 0.1, 0.84, 0.84, k: 0.5, color: const Color(0xFF8A96A3));
        final guard = poly([
          [0.74, 0.86],
          [0.94, 0.86],
          [0.94, 0.9],
          [0.74, 0.9],
        ]);
        fill(guard, yellow, k: 0.8);
        dot(0.84, 0.96, 0.03, yellow);
      } else {
        final staff = poly([
          [0.83, 0.18],
          [0.85, 0.18],
          [0.85, 1.0],
          [0.83, 1.0],
        ]);
        fill(staff, yellow, k: 0.7);
        final orb = Path()..addOval(Rect.fromCircle(center: p(0.84, 0.13), radius: box.width * 0.06));
        fill(orb, yellow);
        line(0.84, 0.04, 0.84, 0.1, k: 1.2);
        line(0.81, 0.07, 0.87, 0.07, k: 1.2);
      }
      // Рука.
      fill(Path()..addOval(Rect.fromCircle(center: p(0.84, 0.72), radius: box.width * 0.05)), Ink.skin);
    } else if (rank == 12) {
      // Цветок.
      final stem = Path()
        ..moveTo(p(0.2, 0.85).dx, p(0.2, 0.85).dy)
        ..quadraticBezierTo(p(0.16, 0.6).dx, p(0.16, 0.6).dy, p(0.2, 0.42).dx, p(0.2, 0.42).dy);
      c.drawPath(
        stem,
        Paint()
          ..color = const Color(0xFF2E7D32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw * 1.6,
      );
      final leaf = curve([
        [0.18, 0.62],
        [0.08, 0.58],
        [0.06, 0.52],
        [0.1, 0.5],
        [0.14, 0.52],
        [0.18, 0.56],
        [0.18, 0.62],
      ]);
      fill(leaf, const Color(0xFF3F9A47), k: 0.6);
      for (var i = 0; i < 5; i++) {
        final a = i / 5 * math.pi * 2;
        final o = Offset(math.cos(a) * 0.045, math.sin(a) * 0.035);
        fill(
          Path()..addOval(Rect.fromCircle(center: p(0.2 + o.dx, 0.38 + o.dy), radius: box.width * 0.04)),
          secondary == Ink.red ? Ink.red : const Color(0xFFD6455A),
          k: 0.6,
        );
      }
      dot(0.2, 0.38, 0.025, yellow);
      fill(Path()..addOval(Rect.fromCircle(center: p(0.22, 0.86), radius: box.width * 0.05)), Ink.skin);
    } else {
      // Алебарда.
      final shaft = poly([
        [0.145, 0.16],
        [0.17, 0.16],
        [0.17, 1.0],
        [0.145, 1.0],
      ]);
      fill(shaft, const Color(0xFF8D5A2B), k: 0.6);
      final axe = curve([
        [0.17, 0.2],
        [0.26, 0.16],
        [0.3, 0.26],
        [0.28, 0.36],
        [0.24, 0.34],
        [0.2, 0.32],
        [0.17, 0.34],
      ]);
      fill(axe, const Color(0xFFCBD3DC), k: 0.7);
      final tip = poly([
        [0.1575, 0.03],
        [0.18, 0.16],
        [0.135, 0.16],
      ]);
      fill(tip, const Color(0xFFCBD3DC), k: 0.7);
      fill(Path()..addOval(Rect.fromCircle(center: p(0.16, 0.74), radius: box.width * 0.05)), Ink.skin);
    }
  }

  void _hairBack() {
    if (rank == 12) {
      // Длинные волосы / вуаль.
      final veil = curve([
        [0.5, 0.14],
        [0.26, 0.14],
        [0.2, 0.4],
        [0.26, 0.58],
        [0.4, 0.56],
        [0.6, 0.56],
        [0.74, 0.58],
        [0.8, 0.4],
        [0.74, 0.14],
        [0.5, 0.14],
      ]);
      fill(veil, yellow);
      for (var i = 0; i < 3; i++) {
        line(0.29 + i * 0.02, 0.3 + i * 0.07, 0.31 + i * 0.02, 0.36 + i * 0.07, k: 0.6);
        line(0.71 - i * 0.02, 0.3 + i * 0.07, 0.69 - i * 0.02, 0.36 + i * 0.07, k: 0.6);
      }
    } else {
      final hair = curve([
        [0.5, 0.2],
        [0.3, 0.2],
        [0.28, 0.36],
        [0.31, 0.48],
        [0.42, 0.44],
        [0.58, 0.44],
        [0.69, 0.48],
        [0.72, 0.36],
        [0.7, 0.2],
        [0.5, 0.2],
      ]);
      fill(hair, yellow);
    }
  }

  void _face() {
    final face = Path()..addOval(r(0.355, 0.2, 0.29, 0.3));
    fill(face, Ink.skin);
    // Глаза.
    for (final x in [0.44, 0.56]) {
      final eye = Path()
        ..addOval(Rect.fromCenter(center: p(x, 0.32), width: box.width * 0.05, height: box.height * 0.022));
      c.drawPath(eye, Paint()..color = const Color(0xFFFFFFFF));
      dot(x + 0.004, 0.32, 0.012, ink);
      line(x - 0.035, 0.295, x + 0.03, 0.29, k: 0.8);
    }
    // Нос.
    final nose = Path()
      ..moveTo(p(0.5, 0.32).dx, p(0.5, 0.32).dy)
      ..lineTo(p(0.485, 0.39).dx, p(0.485, 0.39).dy)
      ..lineTo(p(0.51, 0.395).dx, p(0.51, 0.395).dy);
    c.drawPath(
      nose,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw * 0.7,
    );
    // Щёки.
    dot(0.42, 0.4, 0.028, const Color(0x33E0504A));
    dot(0.58, 0.4, 0.028, const Color(0x33E0504A));

    if (rank == 13) {
      // Борода и усы.
      final beard = curve([
        [0.36, 0.38],
        [0.38, 0.52],
        [0.44, 0.6],
        [0.5, 0.62],
        [0.56, 0.6],
        [0.62, 0.52],
        [0.64, 0.38],
        [0.58, 0.46],
        [0.42, 0.46],
        [0.36, 0.38],
      ]);
      fill(beard, yellow, k: 0.8);
      for (var i = 0; i < 4; i++) {
        line(0.42 + i * 0.05, 0.48, 0.44 + i * 0.04, 0.56, k: 0.5);
      }
      final moustache = Path()
        ..moveTo(p(0.43, 0.44).dx, p(0.43, 0.44).dy)
        ..quadraticBezierTo(p(0.5, 0.405).dx, p(0.5, 0.405).dy, p(0.57, 0.44).dx, p(0.57, 0.44).dy);
      c.drawPath(
        moustache,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw * 1.2
          ..strokeCap = StrokeCap.round,
      );
    } else {
      // Губы.
      final mouth = Path()
        ..moveTo(p(0.46, 0.44).dx, p(0.46, 0.44).dy)
        ..quadraticBezierTo(p(0.5, 0.465).dx, p(0.5, 0.465).dy, p(0.54, 0.44).dx, p(0.54, 0.44).dy);
      c.drawPath(
        mouth,
        Paint()
          ..color = rank == 12 ? Ink.red : const Color(0xFF8A3A2E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw * (rank == 12 ? 1.4 : 0.9)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _headwear() {
    if (rank == 13) {
      // Шапка под короной.
      final cap = curve([
        [0.34, 0.22],
        [0.34, 0.1],
        [0.66, 0.1],
        [0.66, 0.22],
      ]);
      fill(cap, secondary);
      // Корона с зубцами.
      final crown = poly([
        [0.3, 0.23],
        [0.3, 0.1],
        [0.36, 0.16],
        [0.43, 0.04],
        [0.5, 0.14],
        [0.57, 0.04],
        [0.64, 0.16],
        [0.7, 0.1],
        [0.7, 0.23],
      ]);
      fill(crown, yellow);
      final band = poly([
        [0.29, 0.19],
        [0.71, 0.19],
        [0.71, 0.245],
        [0.29, 0.245],
      ]);
      fill(band, yellow);
      dot(0.5, 0.217, 0.022, Ink.red);
      dot(0.39, 0.217, 0.016, Ink.blue);
      dot(0.61, 0.217, 0.016, Ink.blue);
      for (final x in [0.3, 0.43, 0.57, 0.7]) {
        dot(x, x == 0.3 || x == 0.7 ? 0.1 : 0.04, 0.016, yellow);
      }
    } else if (rank == 12) {
      final crown = poly([
        [0.35, 0.2],
        [0.36, 0.12],
        [0.42, 0.16],
        [0.5, 0.07],
        [0.58, 0.16],
        [0.64, 0.12],
        [0.65, 0.2],
      ]);
      fill(crown, yellow);
      final band = poly([
        [0.34, 0.18],
        [0.66, 0.18],
        [0.66, 0.22],
        [0.34, 0.22],
      ]);
      fill(band, yellow);
      dot(0.5, 0.2, 0.016, Ink.red);
      dot(0.5, 0.07, 0.018, const Color(0xFFFFFDF6));
      dot(0.42, 0.2, 0.012, Ink.blue);
      dot(0.58, 0.2, 0.012, Ink.blue);
    } else {
      // Берет с пером.
      final feather = curve([
        [0.6, 0.16],
        [0.7, 0.02],
        [0.86, 0.02],
        [0.92, 0.08],
        [0.82, 0.08],
        [0.72, 0.12],
        [0.6, 0.16],
      ]);
      fill(feather, yellow, k: 0.7);
      line(0.62, 0.15, 0.88, 0.065, k: 0.5);
      final hat = curve([
        [0.3, 0.22],
        [0.3, 0.08],
        [0.7, 0.06],
        [0.72, 0.2],
      ]);
      fill(hat, primary);
      final brim = poly([
        [0.27, 0.2],
        [0.74, 0.18],
        [0.75, 0.235],
        [0.27, 0.245],
      ]);
      fill(brim, secondary);
      dot(0.5, 0.21, 0.014, yellow);
    }
  }
}
