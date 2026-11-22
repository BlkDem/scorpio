import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../game/cards.dart';
import '../../game/game_state.dart';
import '../../state/game_controller.dart';
import '../../state/settings.dart';
import '../../state/sfx.dart';
import '../art/card_painter.dart';
import 'layout.dart';
import 'sprite.dart';

class _Repaint extends ChangeNotifier {
  void ping() => notifyListeners();
}

class _HintVisual {
  final List<int> cards;
  final List<Offset> from;
  final List<Offset> to;
  final Rect? targetRect;
  final bool deal;
  final double t0;

  _HintVisual(this.cards, this.from, this.to, this.targetRect, this.deal, this.t0);
}

class _Spark {
  Offset pos;
  Offset vel;
  final Color color;
  final double life;
  double age = 0;
  final double size;

  _Spark(this.pos, this.vel, this.color, this.life, this.size);
}

/// Игровой стол: рисует карты, анимирует их и обрабатывает касания.
class BoardView extends StatefulWidget {
  final GameController controller;
  final Settings settings;
  final EdgeInsets insets;
  final ValueNotifier<BoardLayout?> layoutOut;

  const BoardView({
    super.key,
    required this.controller,
    required this.settings,
    required this.insets,
    required this.layoutOut,
  });

  @override
  State<BoardView> createState() => BoardViewState();
}

class BoardViewState extends State<BoardView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  // Время анимаций идёт только пока работает тикер.
  double _timeBase = 0;
  double _tickElapsed = 0;
  double _lastTick = 0;
  final _repaint = _Repaint();
  final List<CardSprite> sprites = List.generate(52, CardSprite.new);

  BoardLayout? _layout;
  CardImages? _images;
  ui.Picture? _slots;
  int _seenVersion = -1;
  int _flight = 0;

  // Касания и перетаскивание.
  int? _pointer;
  Offset _down = Offset.zero;
  Offset _pointerPos = Offset.zero;
  Offset _velocity = Offset.zero;
  double _lastMoveT = 0;
  int _pressCol = -1;
  int _pressIdx = -1;
  bool _pressStock = false;
  bool _dragging = false;
  List<int> _dragCards = [];
  Offset _grab = Offset.zero;
  double _dragStep = 0;
  int _dropTarget = -1;
  double _dropGlowT0 = 0;

  _HintVisual? _hint;

  // Победа.
  bool _winFx = false;
  double _winT0 = 0;
  final List<int> _launchQueue = [];
  double _nextLaunch = 0;
  double _nextBurst = 0;
  final List<_Spark> _sparks = [];
  final math.Random _rnd = math.Random();

  double get now => _timeBase + _tickElapsed;

  BoardLayout? get layout => _layout;

  GameController get c => widget.controller;
  Sfx get sfx => c.sfx;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    c.addListener(_onController);
    widget.settings.addListener(_onSettings);
    c.onHint = _showHint;
    c.onReject = (card) {
      sprites[card].shake(now);
      _ensureTicking();
    };
    c.onWin = _startWinFx;
  }

  @override
  void dispose() {
    c.removeListener(_onController);
    widget.settings.removeListener(_onSettings);
    c.onHint = null;
    c.onReject = null;
    c.onWin = null;
    _ticker.dispose();
    _images?.dispose();
    _slots?.dispose();
    super.dispose();
  }

  void _onSettings() {
    final img = _images;
    if (img != null && img.backIndex != widget.settings.backIndex) {
      _images = CardImages.build(img.width, img.pixelRatio, widget.settings.backIndex);
      img.dispose();
      _repaint.ping();
    }
  }

  // ---------------------------------------------------------------- Синхронизация

  void _onController() {
    if (c.version != _seenVersion) _sync();
    _repaint.ping();
  }

  static double _jitterRot(int id) => (((id * 7919) % 97) / 97 - 0.5) * 0.012;
  static Offset _jitterPos(int id) =>
      Offset((((id * 104729) % 89) / 89 - 0.5) * 0.9, (((id * 31337) % 83) / 83 - 0.5) * 0.6);

  void _sync() {
    final l = _layout;
    if (l == null) return;
    _seenVersion = c.version;
    final ev = c.event;
    final targets = l.targets(c.state);
    _hint = null;
    if (ev.kind != ChangeKind.newDeal && ev.kind != ChangeKind.restore) _stopWinFx();

    switch (ev.kind) {
      case ChangeKind.restore:
      case ChangeKind.none:
        _stopWinFx();
        for (var id = 0; id < 52; id++) {
          _applyRest(id, targets[id]);
          sprites[id].snap();
        }
      case ChangeKind.newDeal:
        _stopWinFx();
        _animateNewDeal(targets);
      default:
        _animateChange(targets, ev);
    }
    _ensureTicking();
  }

  void _applyRest(int id, CardTarget t) {
    final s = sprites[id];
    final inColumn = t.column >= 0;
    s.rest = t.pos + (inColumn ? _jitterPos(id) : Offset.zero);
    s.restRot = inColumn ? _jitterRot(id) : 0;
    s.faceUp = t.faceUp;
    s.z = t.z;
  }

  void _animateNewDeal(List<CardTarget> targets) {
    final l = _layout!;
    final t = now;
    final flight = ++_flight;
    final top = l.stockPos(0);
    // Порядок раздачи: ряд за рядом, слева направо.
    final order = List<int>.filled(52, 0);
    for (var id = 0; id < 52; id++) {
      final tg = targets[id];
      order[id] = tg.column >= 0 ? tg.index * 7 + tg.column : 49 + tg.index;
    }
    for (var id = 0; id < 52; id++) {
      final s = sprites[id];
      s.physics = false;
      s.trail.clear();
      s.dragging = false;
      _applyRest(id, targets[id]);
      final tg = targets[id];
      final o = order[id];
      s.pendingOrder = 1000 - o;
      // 1) Собираем колоду.
      final gather = 0.02 + _rnd.nextDouble() * 0.18;
      s.moveTo(
        top,
        0,
        now: t,
        delay: gather,
        dur: 0.34,
        curve: Curves.easeInOutCubic,
        liftPeak: 0.4,
        flight: flight,
        order: o,
      );
      s.flipTo(false, now: t, delay: gather * 0.5, dur: 0.22);
      // 2) Раздаём.
      final dealAt = 0.72 + o * 0.03;
      final dist = (tg.pos - top).distance;
      final dur = (0.26 + dist / 2600).clamp(0.26, 0.5);
      s.moveTo(
        s.rest,
        s.restRot,
        now: t,
        delay: dealAt,
        dur: dur,
        curve: Curves.easeOutCubic,
        arc: math.min(26, dist * 0.06),
        liftPeak: 0.55,
        flight: flight + 1,
        order: o,
        append: true,
      );
      if (s.faceUp) s.flipTo(true, now: t, delay: dealAt + dur * 0.55, dur: 0.3, append: true);
    }
    _flight++;
  }

  void _animateChange(List<CardTarget> targets, BoardEvent ev) {
    final t = now;
    final flight = ++_flight;
    final moved = ev.cards;
    for (var id = 0; id < 52; id++) {
      final s = sprites[id];
      final tg = targets[id];
      s.pendingOrder = 0;
      final oldRest = s.rest;
      final wasFaceUp = s.faceUp;
      _applyRest(id, tg);
      final order = moved.indexOf(id);
      final target = s.rest;
      final changed =
          (oldRest - target).distance > 0.5 || (s.isMoving && (s.finalTarget - target).distance > 0.5) || s.dragging;
      s.dragging = false;
      var flipDelay = 0.0;
      if (changed) {
        final from = s.pos;
        final dist = (target - from).distance;
        var delay = 0.0;
        double dur;
        var arc = 0.0;
        var peak = 0.0;
        Curve curve = Curves.easeOutCubic;
        switch (ev.kind) {
          case ChangeKind.move when order >= 0:
            // Стопка стартует целиком, «хвост» чуть отстаёт за счёт длительности.
            if (ev.dragged) {
              dur = (0.16 + dist / 3000).clamp(0.16, 0.3) + 0.08 * (1 - math.exp(-order / 3));
            } else {
              dur = (0.26 + dist / 2400).clamp(0.26, 0.48) + 0.14 * (1 - math.exp(-order / 3));
              arc = math.min(34, dist * 0.1);
              peak = 0.7;
              curve = Curves.easeInOutCubic;
            }
          case ChangeKind.stockDeal when order >= 0:
            delay = order * 0.12;
            dur = 0.4;
            arc = 30;
            peak = 0.8;
            curve = Curves.easeInOutCubic;
            flipDelay = delay + 0.08;
          case ChangeKind.collect when order >= 0:
            delay = order * 0.05;
            dur = 0.5;
            arc = math.min(60, dist * 0.15);
            peak = 1;
            curve = Curves.easeInOutCubic;
          case ChangeKind.undo:
            dur = (0.24 + dist / 3000).clamp(0.24, 0.4);
            arc = math.min(24, dist * 0.06);
            peak = arc > 0 ? 0.5 : 0;
            curve = Curves.easeInOutCubic;
          default:
            dur = 0.26;
        }
        s.moveTo(
          target,
          s.restRot,
          now: t,
          delay: delay,
          dur: dur,
          curve: curve,
          arc: arc,
          liftPeak: peak,
          flight: flight,
          order: order >= 0 ? order : 0,
        );
      }
      if (wasFaceUp != s.faceUp) {
        if (ev.kind == ChangeKind.move || ev.kind == ChangeKind.collect) {
          flipDelay = ev.kind == ChangeKind.collect ? 0.55 : 0.12;
        }
        s.flipTo(s.faceUp, now: t, delay: flipDelay, dur: 0.34);
      }
    }
  }

  // ---------------------------------------------------------------- Подсказка

  void _showHint(HintResult h) {
    final l = _layout;
    if (l == null || h.move == null) return;
    final s = c.state;
    final m = h.move!;
    if (m.isDeal) {
      final cards = List<int>.of(s.stock);
      final from = [for (final id in cards) sprites[id].rest];
      final to = <Offset>[];
      for (var i = 0; i < cards.length; i++) {
        final col = s.columns[i];
        to.add(col.isEmpty ? l.columnSlot(i).topLeft : l.cardPos(s, i, col.length - 1) + Offset(0, l.upStep));
      }
      _hint = _HintVisual(cards, from, to, l.stockRect.inflate(l.cardW * 0.08), true, now);
    } else {
      final cards = s.columns[m.from].sublist(m.index);
      final from = [for (final id in cards) sprites[id].rest];
      final dst = s.columns[m.to];
      final base = dst.isEmpty ? l.columnSlot(m.to).topLeft : l.cardPos(s, m.to, dst.length - 1) + Offset(0, l.upStep);
      final to = [for (var i = 0; i < cards.length; i++) base + Offset(0, l.upStep * i)];
      final targetRect = dst.isEmpty
          ? l.columnSlot(m.to)
          : Rect.fromLTWH(sprites[dst.last].rest.dx, sprites[dst.last].rest.dy, l.cardW, l.cardH);
      _hint = _HintVisual(cards, from, to, targetRect, false, now);
    }
    _ensureTicking();
  }

  // ---------------------------------------------------------------- Победа

  void _startWinFx() {
    final l = _layout;
    if (l == null) return;
    _winFx = true;
    _winT0 = now;
    _nextLaunch = now + 0.2;
    _nextBurst = now + 0.1;
    _launchQueue.clear();
    // Снимаем карты с «домов» по очереди: короли, затем дамы...
    final suits = c.state.foundations;
    for (var r = 13; r >= 1; r--) {
      for (final suit in suits) {
        _launchQueue.add(makeCard(suit, r));
      }
    }
    _ensureTicking();
  }

  void _stopWinFx() {
    if (!_winFx && _sparks.isEmpty) return;
    _winFx = false;
    _launchQueue.clear();
    _sparks.clear();
    for (final s in sprites) {
      s.physics = false;
      s.trail.clear();
    }
  }

  void _burst(Offset at) {
    const palette = [
      Color(0xFFFFD36E),
      Color(0xFFFF6B6B),
      Color(0xFF7FE7FF),
      Color(0xFFFFFFFF),
      Color(0xFFB98CFF),
      Color(0xFF8CFF9E),
    ];
    final base = palette[_rnd.nextInt(palette.length)];
    final alt = palette[_rnd.nextInt(palette.length)];
    final n = 46 + _rnd.nextInt(24);
    final speed = 160 + _rnd.nextDouble() * 140;
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2 + _rnd.nextDouble() * 0.2;
      final v = speed * (0.7 + _rnd.nextDouble() * 0.5);
      _sparks.add(
        _Spark(
          at,
          Offset(math.cos(a), math.sin(a)) * v,
          i.isEven ? base : alt,
          1.1 + _rnd.nextDouble() * 0.6,
          1.4 + _rnd.nextDouble() * 1.4,
        ),
      );
    }
  }

  void _updateWin(double t, double dt) {
    final l = _layout!;
    final size = l.size;
    if (_winFx) {
      if (_launchQueue.isNotEmpty && t >= _nextLaunch) {
        final id = _launchQueue.removeAt(0);
        final s = sprites[id];
        s.cancelMotion();
        s.physics = true;
        s.face = 1;
        s.lift = 0.6;
        final dir = s.pos.dx < size.width / 2 ? 1.0 : -1.0;
        s.vel = Offset(
          dir * (120 + _rnd.nextDouble() * 260) * (_rnd.nextBool() ? 1 : -0.6),
          -(80 + _rnd.nextDouble() * 380),
        );
        s.spin = (_rnd.nextDouble() - 0.5) * 1.2;
        _nextLaunch = t + 0.11;
      }
      if (t >= _nextBurst && t - _winT0 < 7) {
        _burst(Offset(size.width * (0.15 + _rnd.nextDouble() * 0.7), size.height * (0.12 + _rnd.nextDouble() * 0.4)));
        _nextBurst = t + 0.35 + _rnd.nextDouble() * 0.4;
      }
      if (t - _winT0 > 7 && _launchQueue.isEmpty && !sprites.any((s) => s.physics)) _winFx = false;
    }
    final floor = size.height - l.cardH - 4;
    for (final s in sprites) {
      if (!s.physics) continue;
      s.vel += Offset(0, 1500 * dt);
      s.pos += s.vel * dt;
      s.rot += s.spin * dt;
      if (s.pos.dy > floor) {
        s.pos = Offset(s.pos.dx, floor);
        s.vel = Offset(s.vel.dx * 0.98, -s.vel.dy * 0.72);
        s.spin *= 0.7;
        if (s.vel.dy.abs() < 140) s.vel = Offset(s.vel.dx, -420 - _rnd.nextDouble() * 200);
      }
      s.trailClock += dt;
      if (s.trailClock > 0.03) {
        s.trailClock = 0;
        s.trail.add(s.pos);
        if (s.trail.length > 12) s.trail.removeAt(0);
      }
      if (s.pos.dx < -l.cardW * 1.5 || s.pos.dx > size.width + l.cardW * 0.5) {
        s.physics = false;
        s.trail.clear();
        s.pos = Offset(-l.cardW * 3, -l.cardH * 3);
      }
    }
    for (final p in _sparks) {
      p.age += dt;
      p.vel = p.vel * math.pow(0.35, dt).toDouble() + Offset(0, 260 * dt);
      p.pos += p.vel * dt;
    }
    _sparks.removeWhere((p) => p.age > p.life);
  }

  // ---------------------------------------------------------------- Тикер

  void _ensureTicking() {
    if (!_ticker.isActive) {
      _lastTick = now;
      _ticker.start();
    }
    _repaint.ping();
  }

  void _onTick(Duration elapsed) {
    _tickElapsed = elapsed.inMicroseconds / 1e6;
    final t = now;
    final dt = (t - _lastTick).clamp(0.0, 0.05);
    _lastTick = t;
    var active = false;
    for (final s in sprites) {
      if (s.dragging || s.physics) continue;
      if (s.update(t)) active = true;
    }
    if (_dragging) {
      _updateDrag(dt);
      active = true;
    }
    if (_hint != null) {
      if (t - _hint!.t0 > 3.2) {
        _hint = null;
      } else {
        active = true;
      }
    }
    if (_dropTarget >= 0) active = true;
    if (_layout != null && (_winFx || _sparks.isNotEmpty || sprites.any((s) => s.physics))) {
      _updateWin(t, dt);
      active = true;
    }
    _repaint.ping();
    if (!active) {
      _ticker.stop();
      _timeBase += _tickElapsed;
      _tickElapsed = 0;
    }
  }

  // ---------------------------------------------------------------- Касания

  (int, int) _hitCard(Offset p) {
    final l = _layout!;
    final s = c.state;
    for (var col = 0; col < kColumns; col++) {
      final x = l.colX(col);
      if (p.dx < x || p.dx > x + l.cardW) continue;
      final cards = s.columns[col];
      for (var i = cards.length - 1; i >= 0; i--) {
        final r = sprites[cards[i]].rest;
        if (Rect.fromLTWH(r.dx, r.dy, l.cardW, l.cardH).contains(p)) return (col, i);
      }
    }
    return (-1, -1);
  }

  bool _hitStock(Offset p) {
    final l = _layout!;
    return c.state.stock.isNotEmpty && l.stockRect.inflate(6).contains(p);
  }

  void _onDown(PointerDownEvent e) {
    if (_pointer != null || _layout == null) return;
    if (c.won || _winFx) return;
    _pointer = e.pointer;
    _down = e.localPosition;
    _pointerPos = e.localPosition;
    _velocity = Offset.zero;
    _lastMoveT = now;
    _hint = null;
    _pressStock = _hitStock(e.localPosition);
    final (col, idx) = _pressStock ? (-1, -1) : _hitCard(e.localPosition);
    _pressCol = col;
    _pressIdx = idx;
    if (col >= 0 && idx >= c.state.faceDown[col]) {
      final lead = sprites[c.state.columns[col][idx]];
      _grab = e.localPosition - lead.pos;
    } else if (col >= 0) {
      // Закрытая карта — лёгкое покачивание.
      sprites[c.state.columns[col][idx]].shake(now);
      _ensureTicking();
      _pressCol = -1;
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final t = now;
    final dt = math.max(1e-3, t - _lastMoveT);
    final inst = (e.localPosition - _pointerPos) / dt;
    _velocity = Offset.lerp(_velocity, inst, 0.35)!;
    _lastMoveT = t;
    _pointerPos = e.localPosition;
    if (!_dragging && _pressCol >= 0 && (e.localPosition - _down).distance > 7) _beginDrag();
    if (_dragging) _ensureTicking();
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_dragging) {
      _endDrag();
    } else if (_pressStock) {
      c.dealStock();
    } else if (_pressCol >= 0) {
      if (widget.settings.tapToMove) {
        c.tapCard(_pressCol, _pressIdx);
      } else {
        sprites[c.state.columns[_pressCol][_pressIdx]].shake(now);
        _ensureTicking();
      }
    }
    _pressCol = -1;
    _pressStock = false;
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_dragging) _returnDrag();
    _pressCol = -1;
    _pressStock = false;
  }

  void _beginDrag() {
    final s = c.state;
    if (c.hasPendingCollect) {
      _pressCol = -1;
      return;
    }
    _dragging = true;
    _dragCards = s.columns[_pressCol].sublist(_pressIdx);
    final (_, up) = _layout!.steps(s, _pressCol);
    _dragStep = up;
    for (final id in _dragCards) {
      final sp = sprites[id];
      sp.cancelMotion();
      sp.dragging = true;
    }
    sfx.play(Sound.slide, volume: 0.5);
    sfx.tick();
    _ensureTicking();
  }

  void _updateDrag(double dt) {
    if (_dragCards.isEmpty) return;
    final kLead = 1 - math.exp(-dt * 50);
    final kFollow = 1 - math.exp(-dt * 24);
    final kRot = 1 - math.exp(-dt * 10);
    final targetRot = (_velocity.dx * 0.00016).clamp(-0.13, 0.13);
    Offset? prev;
    for (var i = 0; i < _dragCards.length; i++) {
      final sp = sprites[_dragCards[i]];
      final target = i == 0 ? _pointerPos - _grab : prev! + Offset(0, _dragStep);
      sp.pos = Offset.lerp(sp.pos, target, i == 0 ? kLead : kFollow)!;
      sp.rot += (targetRot * (1 + i * 0.08) - sp.rot) * kRot;
      sp.lift += (1 - sp.lift) * (1 - math.exp(-dt * 14));
      sp.face = 1;
      prev = sp.pos;
    }
    final t = _findDropTarget();
    if (t != _dropTarget) {
      _dropTarget = t;
      _dropGlowT0 = now;
      if (t >= 0) sfx.tick();
    }
  }

  int _findDropTarget() {
    final l = _layout!;
    final s = c.state;
    if (_dragCards.isEmpty) return -1;
    final lead = sprites[_dragCards.first].pos;
    final leadRect = Rect.fromLTWH(lead.dx, lead.dy, l.cardW, l.cardH);
    var best = -1;
    var bestArea = 0.0;
    for (var col = 0; col < kColumns; col++) {
      if (col == _pressCol) continue;
      if (!c.canMove(_pressCol, _pressIdx, col)) continue;
      final cards = s.columns[col];
      final Rect tr;
      if (cards.isEmpty) {
        tr = l.columnSlot(col);
      } else {
        final r = sprites[cards.last].rest;
        tr = Rect.fromLTWH(r.dx, r.dy, l.cardW, l.cardH + l.upStep);
      }
      final inter = tr.inflate(l.cardW * 0.12).intersect(leadRect);
      if (inter.width <= 0 || inter.height <= 0) continue;
      final area = inter.width * inter.height;
      if (area > bestArea) {
        bestArea = area;
        best = col;
      }
    }
    if (best < 0) {
      // Запасной вариант: палец над колонкой.
      for (var col = 0; col < kColumns; col++) {
        final x = l.colX(col);
        if (_pointerPos.dx >= x - l.gap / 2 && _pointerPos.dx <= x + l.cardW + l.gap / 2) {
          if (col != _pressCol && c.canMove(_pressCol, _pressIdx, col)) best = col;
        }
      }
    }
    return best;
  }

  void _endDrag() {
    final target = _findDropTarget();
    _dragging = false;
    _dropTarget = -1;
    final cards = _dragCards;
    _dragCards = [];
    if (target >= 0 && c.tryMove(_pressCol, _pressIdx, target, dragged: true)) {
      return;
    }
    // Если карту почти не сдвинули — считаем это нажатием.
    final moved = (_pointerPos - _down).distance;
    for (final id in cards) {
      sprites[id].dragging = false;
    }
    if (moved < (_layout?.cardW ?? 40) * 0.35 &&
        widget.settings.tapToMove &&
        c.autoDestination(_pressCol, _pressIdx) >= 0) {
      c.tapCard(_pressCol, _pressIdx);
      return;
    }
    _returnCards(cards);
    sfx.play(Sound.place, volume: 0.5);
  }

  void _returnDrag() {
    _dragging = false;
    _dropTarget = -1;
    final cards = _dragCards;
    _dragCards = [];
    for (final id in cards) {
      sprites[id].dragging = false;
    }
    _returnCards(cards);
  }

  void _returnCards(List<int> cards) {
    final t = now;
    final flight = ++_flight;
    for (var i = 0; i < cards.length; i++) {
      final s = sprites[cards[i]];
      s.moveTo(
        s.rest,
        s.restRot,
        now: t,
        delay: i * 0.015,
        dur: 0.38,
        curve: Curves.easeOutBack,
        flight: flight,
        order: i,
      );
    }
    _ensureTicking();
  }

  // ---------------------------------------------------------------- Построение

  void _ensureLayout(Size size, double dpr) {
    final old = _layout;
    if (old != null && old.size == size && old.insets == widget.insets) return;
    final l = BoardLayout(size, widget.insets);
    _layout = l;
    final img = _images;
    if (img == null || (img.width - l.cardW).abs() > 0.5 || img.pixelRatio != dpr) {
      _images = CardImages.build(l.cardW, dpr, widget.settings.backIndex);
      img?.dispose();
    }
    _slots?.dispose();
    _slots = _recordSlots(l);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.layoutOut.value = l;
    });
    // Без анимации переставляем всё на новые места.
    final targets = l.targets(c.state);
    for (var id = 0; id < 52; id++) {
      _applyRest(id, targets[id]);
    }
    if (old == null) {
      _seenVersion = c.version;
      if (!c.ready) {
        // Партия ещё грузится — вся колода рубашкой вверх в резерве.
        for (var id = 0; id < 52; id++) {
          final s = sprites[id];
          s.rest = l.stockPos(0);
          s.restRot = 0;
          s.faceUp = false;
          s.z = 10;
          s.snap();
        }
      } else if (c.event.kind == ChangeKind.newDeal) {
        _animateNewDeal(targets);
        WidgetsBinding.instance.addPostFrameCallback((_) => _ensureTicking());
      } else {
        for (final s in sprites) {
          s.snap();
        }
      }
    } else {
      _stopWinFx();
      for (final s in sprites) {
        s.snap();
      }
    }
  }

  ui.Picture _recordSlots(BoardLayout l) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    CardPainterKit.paintSlot(canvas, l.stockRect);
    for (var i = 0; i < 4; i++) {
      CardPainterKit.paintSlot(canvas, l.foundationRects[i], suit: i);
    }
    for (var col = 0; col < kColumns; col++) {
      CardPainterKit.paintSlot(canvas, l.columnSlot(col), label: 'K');
    }
    return rec.endRecording();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, cons) {
        final size = cons.biggest;
        // Окно ещё не получило размер (первый кадр на Android) — ждём.
        if (!size.isFinite ||
            size.width - widget.insets.horizontal < 120 ||
            size.height - widget.insets.vertical < 160) {
          return const SizedBox.expand();
        }
        _ensureLayout(size, dpr);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onDown,
          onPointerMove: _onMove,
          onPointerUp: _onUp,
          onPointerCancel: _onCancel,
          child: CustomPaint(
            size: cons.biggest,
            painter: _BoardPainter(this, _repaint),
            isComplex: true,
            willChange: true,
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  final BoardViewState v;

  _BoardPainter(this.v, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final l = v._layout;
    final img = v._images;
    if (l == null || img == null) return;
    final t = v.now;
    if (v._slots != null) canvas.drawPicture(v._slots!);

    // Порядок отрисовки.
    final order = List<CardSprite>.of(v.sprites);
    double key(CardSprite s) {
      if (s.physics) return 2e12;
      if (s.dragging) return 1e12 + v._dragCards.indexOf(s.id);
      if (s.isFlying) return 1e7 + s.flight * 1000.0 + s.flightOrder;
      if (s.isMoving) return 1e5 + s.pendingOrder * 2000.0 + s.z;
      return s.z.toDouble();
    }

    order.sort((a, b) => key(a).compareTo(key(b)));

    var glowDrawn = false;
    for (final s in order) {
      if (!glowDrawn && (s.dragging || s.physics)) {
        _dropGlow(canvas, l, t);
        glowDrawn = true;
      }
      if (s.physics) {
        for (var i = 0; i < s.trail.length; i++) {
          final a = (i + 1) / (s.trail.length + 1) * 0.55;
          _card(canvas, l, img, s, t, at: s.trail[i], opacity: a, shadow: false);
        }
      }
      _card(canvas, l, img, s, t);
    }
    if (!glowDrawn) _dropGlow(canvas, l, t);

    _hint(canvas, l, img, t);
    _sparks(canvas);
  }

  void _dropGlow(Canvas canvas, BoardLayout l, double t) {
    final target = v._dropTarget;
    if (target < 0) return;
    final cards = v.c.state.columns[target];
    final Rect r;
    if (cards.isEmpty) {
      r = l.columnSlot(target);
    } else {
      final p = v.sprites[cards.last].rest;
      r = Rect.fromLTWH(p.dx, p.dy, l.cardW, l.cardH);
    }
    final k = ((t - v._dropGlowT0) / 0.15).clamp(0.0, 1.0);
    _glow(canvas, r, l, const Color(0xFF8CF5B0), 0.85 * k);
  }

  void _glow(Canvas canvas, Rect r, BoardLayout l, Color color, double intensity) {
    final rr = RRect.fromRectAndRadius(r.inflate(1.5), Radius.circular(CardPainterKit.radiusFor(l.cardW) + 1.5));
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = color.withValues(alpha: 0.55 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color.withValues(alpha: 0.95 * intensity),
    );
  }

  void _card(
    Canvas canvas,
    BoardLayout l,
    CardImages img,
    CardSprite s,
    double t, {
    Offset? at,
    double opacity = 1,
    bool shadow = true,
  }) {
    final w = l.cardW;
    final h = l.cardH;
    final pos = (at ?? s.pos) + Offset(s.shakeOffset(t, w * 0.06), 0);
    final center = pos + Offset(w / 2, h / 2);

    final angle = (1 - s.face) * math.pi; // 0 — лицо, π — рубашка
    final showFace = angle < math.pi / 2;
    final a = showFace ? angle : angle - math.pi;
    final flipLift = math.sin(angle) * 0.55;
    final lift = math.max(s.lift, flipLift);
    final scale = 1 + 0.055 * lift;
    final squash = math.cos(a).abs();

    if (shadow) {
      final off = Offset(lift * w * 0.05, 1.0 + lift * h * 0.07);
      final blur = 1.1 + lift * w * 0.09;
      canvas.save();
      canvas.translate(center.dx + off.dx, center.dy + off.dy);
      canvas.rotate(s.rot);
      canvas.scale(scale * math.max(0.08, squash), scale);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          Radius.circular(CardPainterKit.radiusFor(w)),
        ),
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, (0.38 - 0.12 * lift) * opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
      canvas.restore();
    }

    final m = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..rotateZ(s.rot)
      ..scaleByDouble(scale, scale, 1, 1);
    if (a.abs() > 1e-4) {
      final persp = Matrix4.identity()
        ..setEntry(3, 2, 0.32 / w)
        ..rotateY(a);
      m.multiply(persp);
    }
    canvas.save();
    canvas.transform(m.storage);
    final image = showFace ? img.faces[s.id] : img.back;
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;
    if (opacity < 1) paint.color = Color.fromRGBO(255, 255, 255, opacity);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(-w / 2, -h / 2, w, h),
      paint,
    );
    // Блик при перевороте.
    if (squash < 0.98) {
      final shine = (1 - squash) * 0.35;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-w / 2, -h / 2, w, h), Radius.circular(CardPainterKit.radiusFor(w))),
        Paint()..color = (a > 0 ? const Color(0xFF000000) : const Color(0xFFFFFFFF)).withValues(alpha: shine * opacity),
      );
    }
    canvas.restore();
  }

  void _hint(Canvas canvas, BoardLayout l, CardImages img, double t) {
    final h = v._hint;
    if (h == null) return;
    final e = t - h.t0;
    final fadeIn = (e / 0.2).clamp(0.0, 1.0);
    final fadeOut = ((3.2 - e) / 0.4).clamp(0.0, 1.0);
    final pulse = 0.65 + 0.35 * math.sin(e * math.pi * 2 * 1.3);
    final k = fadeIn * fadeOut;
    const gold = Color(0xFFFFD36E);

    // Подсветка источника.
    if (h.deal) {
      _glow(canvas, h.targetRect!, l, gold, k * pulse);
    } else if (h.cards.isNotEmpty) {
      final first = v.sprites[h.cards.first].rest;
      final last = v.sprites[h.cards.last].rest;
      final src = Rect.fromLTRB(first.dx, first.dy, first.dx + l.cardW, last.dy + l.cardH);
      _glow(canvas, src, l, gold, k * pulse);
      if (h.targetRect != null) _glow(canvas, h.targetRect!, l, const Color(0xFF8CF5B0), k * pulse);
    }

    // «Призрак» хода.
    const cycle = 1.35;
    final ce = e - 0.25;
    if (ce < 0) return;
    final p = ((ce % cycle) / 1.05).clamp(0.0, 1.0);
    final ease = Curves.easeInOutCubic.transform(p);
    final alpha = math.sin(math.pi * p).clamp(0.0, 1.0) * 0.8 * k;
    if (alpha <= 0.01) return;
    for (var i = 0; i < h.cards.length; i++) {
      final from = h.from[i];
      final to = h.to[i];
      final dist = (to - from).distance;
      final pos = Offset.lerp(from, to, ease)! + Offset(0, -math.min(40, dist * 0.12) * math.sin(math.pi * ease));
      final ghost = v.sprites[h.cards[i]];
      final saved = (ghost.face, ghost.lift);
      ghost.face = 1;
      ghost.lift = 0.6;
      _card(canvas, l, img, ghost, t, at: pos - Offset(ghost.shakeOffset(t, l.cardW * 0.06), 0), opacity: alpha);
      ghost.face = saved.$1;
      ghost.lift = saved.$2;
    }
  }

  void _sparks(Canvas canvas) {
    if (v._sparks.isEmpty) return;
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..strokeCap = StrokeCap.round;
    for (final p in v._sparks) {
      final life = 1 - p.age / p.life;
      final a = (life * life).clamp(0.0, 1.0);
      paint
        ..color = p.color.withValues(alpha: a)
        ..strokeWidth = p.size;
      canvas.drawLine(p.pos, p.pos - p.vel * 0.035, paint);
      canvas.drawCircle(p.pos, p.size * 0.9, paint..color = p.color.withValues(alpha: a * 0.6));
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => old.v != v;
}
