import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../game/cards.dart';
import 'court_art.dart';
import 'suits.dart';

/// Дизайн рубашки.
class BackDesign {
  final String name;
  final Color dark;
  final Color light;
  final Color line;
  final Color emblem;

  const BackDesign(this.name, this.dark, this.light, this.line, this.emblem);

  static const all = [
    BackDesign('Бордо', Color(0xFF5E0E1B), Color(0xFF9E2438), Color(0xFFE7A5A9), Color(0xFFE9C46A)),
    BackDesign('Сапфир', Color(0xFF0E1F4D), Color(0xFF26489A), Color(0xFFA9C0F0), Color(0xFFE9C46A)),
    BackDesign('Изумруд', Color(0xFF07382A), Color(0xFF16704F), Color(0xFF9FDCC0), Color(0xFFE9C46A)),
    BackDesign('Оникс', Color(0xFF0D0D0F), Color(0xFF2E2E34), Color(0xFF8C8C96), Color(0xFFD9B45A)),
  ];
}

/// Отрисовка карт средствами Canvas.
class CardPainterKit {
  static const double aspect = 1.4;

  static double radiusFor(double w) => w * 0.075;

  // ---------------------------------------------------------------- Лицевая сторона

  static void paintFace(Canvas c, Size s, int card) {
    final rect = Offset.zero & s;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radiusFor(s.width)));
    c.save();
    c.clipRRect(rr);
    _paper(c, s, card + 7);

    final rank = rankOf(card);
    final suit = suitOf(card);
    if (s.width < compactBelow) {
      _compactFace(c, s, card);
    } else {
      if (rank >= 11) {
        final frame = Rect.fromLTRB(s.width * 0.255, s.height * 0.07, s.width * 0.745, s.height * 0.93);
        CourtArt.paint(c, frame, card);
      } else {
        _pips(c, s, suit, rank);
      }
      _index(c, s, card);
      c.save();
      c.translate(s.width, s.height);
      c.rotate(math.pi);
      _index(c, s, card);
      c.restore();
    }

    _gloss(c, s);
    c.restore();
    _edge(c, rr);
  }

  static void _paper(Canvas c, Size s, int seed) {
    final rect = Offset.zero & s;
    c.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          const [Color(0xFFFFFEFA), Color(0xFFFAF6EC), Color(0xFFF1EBDD)],
          const [0, 0.55, 1],
        ),
    );
    // Фактура бумаги: мелкое зерно.
    final rnd = math.Random(seed);
    final n = (s.width * s.height * 0.35).round();
    final dark = Float32List(n * 2);
    final light = Float32List(n * 2);
    for (var i = 0; i < n; i++) {
      dark[i * 2] = rnd.nextDouble() * s.width;
      dark[i * 2 + 1] = rnd.nextDouble() * s.height;
      light[i * 2] = rnd.nextDouble() * s.width;
      light[i * 2 + 1] = rnd.nextDouble() * s.height;
    }
    c.drawRawPoints(
      ui.PointMode.points,
      dark,
      Paint()
        ..color = const Color(0x0C6B5A3A)
        ..strokeWidth = 0.6,
    );
    c.drawRawPoints(
      ui.PointMode.points,
      light,
      Paint()
        ..color = const Color(0x14FFFFFF)
        ..strokeWidth = 0.6,
    );
  }

  static void _gloss(Canvas c, Size s) {
    final rect = Offset.zero & s;
    c.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(s.width, s.height),
          const [Color(0x00FFFFFF), Color(0x16FFFFFF), Color(0x00FFFFFF), Color(0x08000000)],
          const [0.0, 0.35, 0.6, 1.0],
        ),
    );
  }

  static void _edge(Canvas c, RRect rr) {
    c.drawRRect(
      rr.deflate(0.3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0x40594A30),
    );
  }

  static TextPainter _rankText(int rank, Color color, double size) {
    return TextPainter(
      text: TextSpan(
        text: rankLabel(rank),
        style: TextStyle(
          fontFamily: 'Baskerville',
          fontSize: size,
          height: 1.0,
          color: color,
          fontWeight: FontWeight.w700,
          fontVariations: const [ui.FontVariation('wght', 700)],
          letterSpacing: rank == 10 ? -size * 0.1 : 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// Карты уже этой ширины (логические пиксели, телефоны) рисуются «крупным
  /// шрифтом»: классический индекс и очки на них не читаются.
  static const double compactBelow = 76;

  /// Крупный индекс одной строкой (достоинство слева, масть справа) в верхней
  /// трети карты — она видна даже в плотном веере; ниже — большая масть
  /// или погрудный портрет фигуры.
  static void _compactFace(Canvas c, Size s, int card) {
    final rank = rankOf(card);
    final suit = suitOf(card);
    final color = Ink.suit(suit);
    final paint = Paint()..color = color;
    final w = s.width, h = s.height;

    // Индекс должен целиком (с хвостом Q и J) уместиться в верхние ~25% —
    // столько остаётся видно в самом плотном веере.
    final fs = w * 0.40;
    final tp = _rankText(rank, color, fs);
    c.save();
    c.translate(w * 0.07, -fs * 0.035);
    if (rank == 10) c.scale(0.78, 1.0);
    tp.paint(c, Offset.zero);
    c.restore();

    final pipW = w * 0.29;
    final pip = Rect.fromLTWH(w * 0.93 - pipW, h * 0.04, pipW, pipW * (suit == kDiamonds ? 1.12 : 1.0));
    c.drawPath(SuitPaths.fit(suit, pip), paint);

    if (rank >= 11) {
      final fw = w * 0.66;
      CourtArt.paintBust(c, Rect.fromLTWH((w - fw) / 2, h * 0.36, fw, h * 0.58), card);
    } else {
      final big = w * (rank == 1 ? 0.62 : 0.5);
      final r = Rect.fromCenter(
        center: Offset(w / 2, h * 0.655),
        width: big,
        height: big * (suit == kDiamonds ? 1.15 : 1.0),
      );
      c.drawPath(SuitPaths.fit(suit, r), paint);
    }
  }

  static void _index(Canvas c, Size s, int card) {
    final rank = rankOf(card);
    final suit = suitOf(card);
    final color = Ink.suit(suit);
    final fs = s.width * 0.235;
    final tp = _rankText(rank, color, fs);
    final cx = s.width * 0.13;
    final top = s.height * 0.034;
    c.save();
    c.translate(cx, top);
    if (rank == 10) c.scale(0.8, 1.0);
    tp.paint(c, Offset(-tp.width / 2, 0));
    c.restore();

    final pipW = s.width * 0.14;
    final pipTop = top + fs * 1.0;
    final pr = Rect.fromLTWH(cx - pipW / 2, pipTop, pipW, pipW * (suit == kDiamonds ? 1.15 : 1.0));
    c.drawPath(SuitPaths.fit(suit, pr), Paint()..color = color);
  }

  static const _l = 0.35, _c = 0.5, _r = 0.65;

  static const Map<int, List<(double, double)>> _layouts = {
    2: [(_c, 0), (_c, 1)],
    3: [(_c, 0), (_c, 0.5), (_c, 1)],
    4: [(_l, 0), (_r, 0), (_l, 1), (_r, 1)],
    5: [(_l, 0), (_r, 0), (_c, 0.5), (_l, 1), (_r, 1)],
    6: [(_l, 0), (_r, 0), (_l, 0.5), (_r, 0.5), (_l, 1), (_r, 1)],
    7: [(_l, 0), (_r, 0), (_c, 0.25), (_l, 0.5), (_r, 0.5), (_l, 1), (_r, 1)],
    8: [(_l, 0), (_r, 0), (_c, 0.25), (_l, 0.5), (_r, 0.5), (_c, 0.75), (_l, 1), (_r, 1)],
    9: [(_l, 0), (_r, 0), (_l, 1 / 3), (_r, 1 / 3), (_c, 0.5), (_l, 2 / 3), (_r, 2 / 3), (_l, 1), (_r, 1)],
    10: [
      (_l, 0),
      (_r, 0),
      (_c, 1 / 6),
      (_l, 1 / 3),
      (_r, 1 / 3),
      (_l, 2 / 3),
      (_r, 2 / 3),
      (_c, 5 / 6),
      (_l, 1),
      (_r, 1),
    ],
  };

  static void _pips(Canvas c, Size s, int suit, int rank) {
    final color = Ink.suit(suit);
    final paint = Paint()..color = color;
    if (rank == 1) {
      final big = s.width * (suit == kSpades ? 0.5 : 0.4);
      final center = Offset(s.width / 2, s.height / 2);
      if (suit == kSpades) {
        // Туз пик — с орнаментом.
        final ring = s.width * 0.34;
        c.drawCircle(
          center,
          ring,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.width * 0.012
            ..color = const Color(0x66A77A1D),
        );
        for (var i = 0; i < 24; i++) {
          final a = i / 24 * math.pi * 2;
          c.drawCircle(
            center + Offset(math.cos(a), math.sin(a)) * ring,
            s.width * 0.012,
            Paint()..color = Ink.goldDark,
          );
        }
      }
      final rect = Rect.fromCenter(center: center, width: big, height: big * (suit == kDiamonds ? 1.2 : 1.05));
      _pipShaded(c, SuitPaths.fit(suit, rect), color, rect);
      return;
    }
    final layout = _layouts[rank]!;
    final pw = s.width * (rank <= 3 ? 0.2 : (rank >= 9 ? 0.165 : 0.18));
    final ph = pw * (suit == kDiamonds ? 1.18 : 1.06);
    final top = s.height * 0.205;
    final bottom = s.height * 0.795;
    for (final (x, y) in layout) {
      final cx = x * s.width;
      final cy = top + (bottom - top) * y;
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: pw, height: ph);
      if (y > 0.5) {
        c.save();
        c.translate(cx, cy);
        c.rotate(math.pi);
        c.translate(-cx, -cy);
        c.drawPath(SuitPaths.fit(suit, rect), paint);
        c.restore();
      } else {
        c.drawPath(SuitPaths.fit(suit, rect), paint);
      }
    }
  }

  static void _pipShaded(Canvas c, Path path, Color color, Rect rect) {
    c.drawPath(path, Paint()..color = color);
    c.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          const [Color(0x30FFFFFF), Color(0x00FFFFFF), Color(0x22000000)],
          const [0, 0.5, 1],
        ),
    );
  }

  // ---------------------------------------------------------------- Рубашка

  static void paintBack(Canvas c, Size s, BackDesign d) {
    final rect = Offset.zero & s;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radiusFor(s.width)));
    c.save();
    c.clipRRect(rr);
    _paper(c, s, 999);

    final inset = s.width * 0.06;
    final inner = rect.deflate(inset);
    final innerRR = RRect.fromRectAndRadius(inner, Radius.circular(radiusFor(s.width) * 0.55));
    c.save();
    c.clipRRect(innerRR);
    c.drawRect(inner, Paint()..shader = ui.Gradient.radial(inner.center, inner.longestSide * 0.65, [d.light, d.dark]));

    // Сетка тонких диагоналей.
    final grid = Paint()
      ..color = d.line.withValues(alpha: 0.22)
      ..strokeWidth = math.max(0.3, s.width * 0.004);
    final step = s.width * 0.055;
    for (var x = -s.height; x < s.width + s.height; x += step) {
      c.drawLine(Offset(x, 0), Offset(x + s.height, s.height), grid);
      c.drawLine(Offset(x, s.height), Offset(x + s.height, 0), grid);
    }

    // Гильош: розетки (гипотрохоиды).
    final center = inner.center;
    _guilloche(c, center, inner.width * 0.47, 7, 0.62, d.line.withValues(alpha: 0.45), s.width * 0.005);
    _guilloche(c, center, inner.width * 0.36, 11, 0.5, d.line.withValues(alpha: 0.55), s.width * 0.004);
    _guilloche(c, center, inner.width * 0.24, 9, 0.7, d.emblem.withValues(alpha: 0.5), s.width * 0.004);

    // Волнистые бордюры.
    final wave = Paint()
      ..color = d.line.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.3, s.width * 0.005);
    for (var k = 0; k < 2; k++) {
      final band = inner.deflate(s.width * (0.035 + k * 0.012));
      c.drawPath(_wavyRect(band, s.width * 0.012, 20 + k * 2, k * math.pi), wave);
    }

    // Медальон со скорпионом.
    final medal = Rect.fromCenter(center: center, width: inner.width * 0.56, height: inner.width * 0.56);
    c.drawOval(
      medal,
      Paint()
        ..shader = ui.Gradient.radial(medal.center, medal.width / 2, [
          d.dark.withValues(alpha: 0.95),
          d.dark.withValues(alpha: 0.7),
        ]),
    );
    c.drawOval(
      medal,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.012
        ..shader = _foil(medal),
    );
    c.drawOval(
      medal.deflate(s.width * 0.022),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.005
        ..color = d.emblem.withValues(alpha: 0.7),
    );
    ScorpionEmblem.paint(c, medal.deflate(medal.width * 0.12), _foil(medal));

    c.restore();

    // Рамка внутреннего поля.
    c.drawRRect(
      innerRR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.012
        ..color = d.dark,
    );
    c.drawRRect(
      innerRR.deflate(s.width * 0.018),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.006
        ..shader = _foil(inner),
    );

    _gloss(c, s);
    c.restore();
    _edge(c, rr);
  }

  static Shader _foil(Rect r) => ui.Gradient.linear(
    r.topLeft,
    r.bottomRight,
    const [Color(0xFFFFF0B8), Color(0xFFE2B04A), Color(0xFF9C6E1E), Color(0xFFF6D98A), Color(0xFFB8862B)],
    const [0, 0.3, 0.5, 0.72, 1],
  );

  static void _guilloche(Canvas c, Offset center, double radius, int lobes, double depth, Color color, double width) {
    // Гипотрохоида: R/r = lobes, d — глубина.
    final path = Path();
    const steps = 720;
    final big = radius;
    final small = big / lobes;
    final d = small * depth * lobes * 0.35;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * math.pi * 2;
      final x = (big - small) * math.cos(t) + d * math.cos((big - small) / small * t);
      final y = (big - small) * math.sin(t) - d * math.sin((big - small) / small * t);
      final o = center + Offset(x, y) * (radius / (big - small + d));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.3, width);
    for (var k = 0; k < 3; k++) {
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(k * math.pi / lobes / 3);
      c.translate(-center.dx, -center.dy);
      c.drawPath(path, paint);
      c.restore();
    }
  }

  static Path _wavyRect(Rect r, double amp, int waves, double phase) {
    final path = Path();
    final perim = 2 * (r.width + r.height);
    const steps = 400;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      var dist = t * perim;
      Offset base;
      Offset normal;
      if (dist < r.width) {
        base = Offset(r.left + dist, r.top);
        normal = const Offset(0, 1);
      } else if ((dist -= r.width) < r.height) {
        base = Offset(r.right, r.top + dist);
        normal = const Offset(-1, 0);
      } else if ((dist -= r.height) < r.width) {
        base = Offset(r.right - dist, r.bottom);
        normal = const Offset(0, -1);
      } else {
        dist -= r.width;
        base = Offset(r.left, r.bottom - dist);
        normal = const Offset(1, 0);
      }
      final o = base + normal * (amp * math.sin(t * waves * 2 * math.pi + phase));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    path.close();
    return path;
  }

  // ---------------------------------------------------------------- Слоты

  /// Пустое место на сукне (тиснёная рамка).
  static void paintSlot(Canvas c, Rect r, {String? label, int? suit, double opacity = 1}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radiusFor(r.width)));
    c.drawRRect(rr, Paint()..color = Color.fromRGBO(0, 0, 0, 0.16 * opacity));
    c.drawRRect(
      rr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Color.fromRGBO(255, 255, 255, 0.16 * opacity),
    );
    if (suit != null) {
      final w = r.width * 0.42;
      final pr = Rect.fromCenter(center: r.center, width: w, height: w * 1.05);
      c.drawPath(SuitPaths.fit(suit, pr), Paint()..color = Color.fromRGBO(255, 255, 255, 0.13 * opacity));
    }
    if (label != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'Baskerville',
            fontSize: r.width * 0.42,
            fontWeight: FontWeight.w700,
            fontVariations: const [ui.FontVariation('wght', 700)],
            color: Color.fromRGBO(255, 255, 255, 0.14 * opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, r.center - Offset(tp.width / 2, tp.height / 2));
    }
  }
}

/// Эмблема-скорпион (вид сверху, хвост закручен над спиной).
class ScorpionEmblem {
  static void paint(Canvas c, Rect box, Shader foil) {
    Offset p(double x, double y) => Offset(box.left + x * box.width, box.top + y * box.height);
    final w = box.width;
    final fill = Paint()..shader = foil;
    final limb = Paint()
      ..shader = foil
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w * 0.035;

    // Ноги: 4 пары.
    for (var i = 0; i < 4; i++) {
      final y = 0.44 + i * 0.055;
      for (final side in [-1.0, 1.0]) {
        final path = Path()
          ..moveTo(p(0.5 + side * 0.06, y).dx, p(0.5 + side * 0.06, y).dy)
          ..lineTo(
            p(0.5 + side * (0.2 + i * 0.01), y - 0.05 + i * 0.01).dx,
            p(0.5 + side * (0.2 + i * 0.01), y - 0.05 + i * 0.01).dy,
          )
          ..lineTo(
            p(0.5 + side * (0.27 + i * 0.015), y + 0.04 + i * 0.03).dx,
            p(0.5 + side * (0.27 + i * 0.015), y + 0.04 + i * 0.03).dy,
          );
        c.drawPath(path, limb..strokeWidth = w * 0.028);
      }
    }

    // Клешни.
    for (final side in [-1.0, 1.0]) {
      final arm = Path()
        ..moveTo(p(0.5 + side * 0.05, 0.36).dx, p(0.5 + side * 0.05, 0.36).dy)
        ..lineTo(p(0.5 + side * 0.18, 0.3).dx, p(0.5 + side * 0.18, 0.3).dy)
        ..lineTo(p(0.5 + side * 0.24, 0.2).dx, p(0.5 + side * 0.24, 0.2).dy);
      c.drawPath(arm, limb..strokeWidth = w * 0.045);
      // Клешня: две дуги.
      final cx = 0.5 + side * 0.24;
      final claw = Path()
        ..moveTo(p(cx - side * 0.05, 0.2).dx, p(cx - side * 0.05, 0.2).dy)
        ..quadraticBezierTo(
          p(cx - side * 0.09, 0.05).dx,
          p(cx - side * 0.09, 0.05).dy,
          p(cx + side * 0.01, 0.02).dx,
          p(cx + side * 0.01, 0.02).dy,
        )
        ..quadraticBezierTo(
          p(cx - side * 0.03, 0.1).dx,
          p(cx - side * 0.03, 0.1).dy,
          p(cx - side * 0.01, 0.16).dx,
          p(cx - side * 0.01, 0.16).dy,
        )
        ..quadraticBezierTo(
          p(cx + side * 0.06, 0.08).dx,
          p(cx + side * 0.06, 0.08).dy,
          p(cx + side * 0.08, 0.04).dx,
          p(cx + side * 0.08, 0.04).dy,
        )
        ..quadraticBezierTo(
          p(cx + side * 0.1, 0.17).dx,
          p(cx + side * 0.1, 0.17).dy,
          p(cx + side * 0.04, 0.23).dx,
          p(cx + side * 0.04, 0.23).dy,
        )
        ..close();
      c.drawPath(claw, fill);
    }

    // Головогрудь и брюшко.
    c.drawOval(Rect.fromCenter(center: p(0.5, 0.39), width: w * 0.17, height: w * 0.13), fill);
    for (var i = 0; i < 6; i++) {
      final y = 0.46 + i * 0.045;
      final ww = 0.2 - (i - 2).abs() * 0.015 - (i > 3 ? 0.03 : 0);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p(0.5, y), width: w * ww, height: w * 0.05),
          Radius.circular(w * 0.025),
        ),
        fill,
      );
    }

    // Хвост — сегменты по дуге, жало над спиной.
    final segs = <Offset>[p(0.5, 0.74), p(0.52, 0.8), p(0.57, 0.85), p(0.64, 0.86), p(0.7, 0.82), p(0.73, 0.75)];
    for (var i = 0; i < segs.length; i++) {
      final r = w * (0.042 - i * 0.002);
      c.drawCircle(segs[i], r, fill);
    }
    // Жало.
    final sting = Path()
      ..moveTo(p(0.70, 0.73).dx, p(0.70, 0.73).dy)
      ..quadraticBezierTo(p(0.74, 0.64).dx, p(0.74, 0.64).dy, p(0.68, 0.6).dx, p(0.68, 0.6).dy)
      ..quadraticBezierTo(p(0.77, 0.62).dx, p(0.77, 0.62).dy, p(0.77, 0.73).dx, p(0.77, 0.73).dy)
      ..close();
    c.drawPath(sting, fill);
  }
}

/// Кэш растровых изображений всех карт под конкретный размер.
class CardImages {
  final double width;
  final double height;
  final double pixelRatio;
  final int backIndex;
  final List<ui.Image> faces;
  final ui.Image back;

  CardImages._(this.width, this.height, this.pixelRatio, this.backIndex, this.faces, this.back);

  static CardImages build(double width, double pixelRatio, int backIndex) {
    final height = width * CardPainterKit.aspect;
    final pr = pixelRatio * 1.15;
    final pw = (width * pr).ceil();
    final ph = (height * pr).ceil();
    ui.Image render(void Function(Canvas c, Size s) draw) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.scale(pw / width, ph / height);
      draw(c, Size(width, height));
      final pic = rec.endRecording();
      final img = pic.toImageSync(pw, ph);
      pic.dispose();
      return img;
    }

    final faces = List<ui.Image>.generate(52, (i) => render((c, s) => CardPainterKit.paintFace(c, s, i)));
    final back = render((c, s) => CardPainterKit.paintBack(c, s, BackDesign.all[backIndex]));
    return CardImages._(width, height, pixelRatio, backIndex, faces, back);
  }

  void dispose() {
    for (final f in faces) {
      f.dispose();
    }
    back.dispose();
  }
}
