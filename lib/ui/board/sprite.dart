import 'dart:math' as math;

import 'package:flutter/animation.dart';

class _Motion {
  final Offset to;
  final double toRot;
  final double t0;
  final double dur;
  final Curve curve;
  final double arc;
  final double liftPeak;
  final int flight;
  final int order;
  bool started = false;
  Offset from = Offset.zero;
  double fromRot = 0;
  double fromLift = 0;

  _Motion(this.to, this.toRot, this.t0, this.dur, this.curve, this.arc, this.liftPeak, this.flight, this.order);
}

class _Flip {
  final bool toFace;
  final double t0;
  final double dur;
  bool started = false;
  double from = 0;

  _Flip(this.toFace, this.t0, this.dur);
}

/// Визуальное состояние одной карты.
class CardSprite {
  final int id;

  Offset pos = Offset.zero;
  double rot = 0;

  /// 0 — видна рубашка, 1 — лицо.
  double face = 0;

  /// 0..1 — насколько карта приподнята над столом.
  double lift = 0;

  // Покой.
  Offset rest = Offset.zero;
  double restRot = 0;
  bool faceUp = false;
  int z = 0;

  final List<_Motion> _motions = [];
  final List<_Flip> _flips = [];

  /// Порядок карты в «колоде ожидания» (для раздачи).
  int pendingOrder = 0;

  double shakeT0 = -10;
  bool dragging = false;

  // Физика победного каскада.
  bool physics = false;
  Offset vel = Offset.zero;
  double spin = 0;
  final List<Offset> trail = [];
  double trailClock = 0;

  CardSprite(this.id);

  bool get isMoving => _motions.isNotEmpty;
  bool get isFlying => _motions.isNotEmpty && _motions.first.started;
  int get flight => _motions.isEmpty ? 0 : _motions.first.flight;
  int get flightOrder => _motions.isEmpty ? 0 : _motions.first.order;
  Offset get finalTarget => _motions.isEmpty ? pos : _motions.last.to;

  void moveTo(
    Offset to,
    double toRot, {
    required double now,
    double delay = 0,
    double dur = 0.3,
    Curve curve = Curves.easeOutCubic,
    double arc = 0,
    double liftPeak = 0,
    int flight = 0,
    int order = 0,
    bool append = false,
  }) {
    if (!append) _motions.clear();
    _motions.add(_Motion(to, toRot, now + delay, math.max(0.001, dur), curve, arc, liftPeak, flight, order));
  }

  void flipTo(bool toFace, {required double now, double delay = 0, double dur = 0.32, bool append = false}) {
    if (!append) _flips.clear();
    _flips.add(_Flip(toFace, now + delay, dur));
  }

  void snap() {
    _motions.clear();
    _flips.clear();
    physics = false;
    dragging = false;
    trail.clear();
    pos = rest;
    rot = restRot;
    face = faceUp ? 1 : 0;
    lift = 0;
  }

  void cancelMotion() => _motions.clear();

  void shake(double now) => shakeT0 = now;

  double shakeOffset(double now, double amp) {
    final t = now - shakeT0;
    if (t < 0 || t > 0.4) return 0;
    final p = t / 0.4;
    return math.sin(t * 52) * amp * (1 - p) * (1 - p);
  }

  /// Продвигает анимации. Возвращает true, если карта ещё в движении.
  bool update(double now) {
    var active = false;
    while (_motions.isNotEmpty) {
      final m = _motions.first;
      if (now < m.t0) {
        active = true;
        break;
      }
      if (!m.started) {
        m.started = true;
        m.from = pos;
        m.fromRot = rot;
        m.fromLift = lift;
      }
      final p = ((now - m.t0) / m.dur).clamp(0.0, 1.0);
      final e = m.curve.transform(p);
      final bump = math.sin(math.pi * p);
      pos = Offset.lerp(m.from, m.to, e)! + Offset(0, -m.arc * bump);
      rot = m.fromRot + (m.toRot - m.fromRot) * e + (m.arc > 0 ? bump * 0.05 * (m.to.dx > m.from.dx ? 1 : -1) : 0);
      lift = m.fromLift * (1 - e) + m.liftPeak * bump;
      if (p >= 1) {
        pos = m.to;
        rot = m.toRot;
        lift = 0;
        _motions.removeAt(0);
        continue;
      }
      active = true;
      break;
    }
    while (_flips.isNotEmpty) {
      final f = _flips.first;
      if (now < f.t0) {
        active = true;
        break;
      }
      if (!f.started) {
        f.started = true;
        f.from = face;
      }
      final p = ((now - f.t0) / f.dur).clamp(0.0, 1.0);
      final e = Curves.easeInOutCubic.transform(p);
      final to = f.toFace ? 1.0 : 0.0;
      face = f.from + (to - f.from) * e;
      if (p >= 1) {
        face = to;
        _flips.removeAt(0);
        continue;
      }
      active = true;
      break;
    }
    if (now - shakeT0 < 0.4) active = true;
    return active;
  }
}
