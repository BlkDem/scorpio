import 'dart:typed_data';
import 'dart:ui';

import '../../game/cards.dart';

/// Векторные контуры мастей в единичном квадрате (0..1).
class SuitPaths {
  static final List<Path> _unit = [_spade(), _heart(), _diamond(), _club()];

  static Path unit(int suit) => _unit[suit];

  /// Контур масти, вписанный в прямоугольник [r].
  static Path fit(int suit, Rect r) {
    final m = Float64List(16)
      ..[0] = r.width
      ..[5] = r.height
      ..[10] = 1
      ..[12] = r.left
      ..[13] = r.top
      ..[15] = 1;
    return _unit[suit].transform(m);
  }

  static Path _heart() {
    return Path()
      ..moveTo(0.5, 0.96)
      ..cubicTo(0.36, 0.80, 0.0, 0.60, 0.0, 0.31)
      ..cubicTo(0.0, 0.12, 0.14, 0.02, 0.28, 0.02)
      ..cubicTo(0.40, 0.02, 0.47, 0.09, 0.5, 0.19)
      ..cubicTo(0.53, 0.09, 0.60, 0.02, 0.72, 0.02)
      ..cubicTo(0.86, 0.02, 1.0, 0.12, 1.0, 0.31)
      ..cubicTo(1.0, 0.60, 0.64, 0.80, 0.5, 0.96)
      ..close();
  }

  static Path _diamond() {
    return Path()
      ..moveTo(0.5, 0.0)
      ..quadraticBezierTo(0.68, 0.28, 0.9, 0.5)
      ..quadraticBezierTo(0.68, 0.72, 0.5, 1.0)
      ..quadraticBezierTo(0.32, 0.72, 0.1, 0.5)
      ..quadraticBezierTo(0.32, 0.28, 0.5, 0.0)
      ..close();
  }

  static Path _spade() {
    return Path()
      ..moveTo(0.5, 0.0)
      ..cubicTo(0.60, 0.16, 1.0, 0.34, 1.0, 0.60)
      ..cubicTo(1.0, 0.76, 0.87, 0.84, 0.74, 0.84)
      ..cubicTo(0.63, 0.84, 0.56, 0.79, 0.525, 0.72)
      ..cubicTo(0.53, 0.84, 0.58, 0.94, 0.70, 1.0)
      ..lineTo(0.30, 1.0)
      ..cubicTo(0.42, 0.94, 0.47, 0.84, 0.475, 0.72)
      ..cubicTo(0.44, 0.79, 0.37, 0.84, 0.26, 0.84)
      ..cubicTo(0.13, 0.84, 0.0, 0.76, 0.0, 0.60)
      ..cubicTo(0.0, 0.34, 0.40, 0.16, 0.5, 0.0)
      ..close();
  }

  static Path _club() {
    final p = Path()
      ..addOval(Rect.fromCircle(center: const Offset(0.5, 0.25), radius: 0.235))
      ..addOval(Rect.fromCircle(center: const Offset(0.245, 0.585), radius: 0.235))
      ..addOval(Rect.fromCircle(center: const Offset(0.755, 0.585), radius: 0.235))
      ..addOval(Rect.fromCircle(center: const Offset(0.5, 0.52), radius: 0.13));
    final stem = Path()
      ..moveTo(0.465, 0.52)
      ..cubicTo(0.465, 0.80, 0.42, 0.93, 0.29, 1.0)
      ..lineTo(0.71, 1.0)
      ..cubicTo(0.58, 0.93, 0.535, 0.80, 0.535, 0.52)
      ..close();
    return Path.combine(PathOperation.union, p, stem);
  }
}

/// Цвета печати.
class Ink {
  static const red = Color(0xFFC0182B);
  static const redDark = Color(0xFF8E0F1F);
  static const black = Color(0xFF15171C);
  static const blue = Color(0xFF1E3D8C);
  static const gold = Color(0xFFE8B64A);
  static const goldDark = Color(0xFFA77A1D);
  static const skin = Color(0xFFF6DCB8);

  static Color suit(int suit) => isRedSuit(suit) ? red : black;
}
