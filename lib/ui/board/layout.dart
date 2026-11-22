import 'dart:math' as math;
import 'package:flutter/painting.dart';

import '../../game/cards.dart';
import '../../game/game_state.dart';
import '../art/card_painter.dart';

/// Целевая позиция карты на столе.
class CardTarget {
  final Offset pos;
  final bool faceUp;
  final int z;
  final int column; // -1 — не в колонке
  final int index;

  const CardTarget(this.pos, this.faceUp, this.z, this.column, this.index);
}

/// Геометрия стола: размеры карт, колонки, резерв и «дом».
class BoardLayout {
  final Size size;
  final EdgeInsets insets;

  late final bool wide;
  late final double cardW;
  late final double cardH;
  late final double gap;
  late final double left;
  late final double topY;
  late final double tableauY;
  late final double bottomY;
  late final double downStep;
  late final double upStep;
  late final Rect stockRect;
  late final List<Rect> foundationRects;
  late final Rect infoRect;

  BoardLayout(this.size, this.insets) {
    final w = size.width - insets.horizontal;
    final h = size.height - insets.vertical;
    wide = w / h > 1.25;
    const margin = 8.0;
    if (!wide) {
      // Портрет: резерв и «дом» сверху.
      const gapK = 0.085;
      final byW = (w - margin * 2) / (7 + 6 * gapK);
      final byH = h / ((1 + 0.2 + 1 + 3.9) * CardPainterKit.aspect);
      cardW = math.min(math.min(byW, byH), 150);
      cardH = cardW * CardPainterKit.aspect;
      gap = cardW * gapK;
      final total = cardW * 7 + gap * 6;
      left = insets.left + (w - total) / 2;
      topY = insets.top + 6;
      tableauY = topY + cardH + cardH * 0.2;
      stockRect = Rect.fromLTWH(colX(0), topY, cardW, cardH);
      foundationRects = [for (var i = 0; i < 4; i++) Rect.fromLTWH(colX(3 + i), topY, cardW, cardH)];
      infoRect = Rect.fromLTRB(colX(1), topY, colX(3) - gap, topY + cardH);
    } else {
      // Ландшафт: резерв слева, «дом» справа веером.
      const gapK = 0.1;
      const side = 0.35;
      final byW = (w - margin * 2) / (9 + 6 * gapK + 2 * side);
      final byH = h / ((1 + 3.4) * CardPainterKit.aspect);
      cardW = math.min(math.min(byW, byH), 150);
      cardH = cardW * CardPainterKit.aspect;
      gap = cardW * gapK;
      final total = cardW * 9 + gap * 6 + cardW * side * 2;
      final x0 = insets.left + (w - total) / 2;
      left = x0 + cardW * (1 + side);
      topY = insets.top + 8;
      tableauY = topY;
      stockRect = Rect.fromLTWH(x0, topY, cardW, cardH);
      final fx = colX(6) + cardW + cardW * side;
      final fStep = math.min(cardH * 0.62, (h - 16 - cardH) / 3);
      foundationRects = [for (var i = 0; i < 4; i++) Rect.fromLTWH(fx, topY + i * fStep, cardW, cardH)];
      infoRect = Rect.fromLTWH(x0 - cardW * 0.1, topY + cardH + 12, cardW * 1.2, cardH * 1.6);
    }
    bottomY = size.height - insets.bottom - 6;
    downStep = cardH * 0.11;
    // Шаг веера подбираем под свободное место: длинные колонки потом сожмутся.
    upStep = ((bottomY - tableauY - cardH - downStep * 3) / 12).clamp(cardH * 0.28, cardH * 0.4);
  }

  double colX(int c) => left + c * (cardW + gap);

  Size get cardSize => Size(cardW, cardH);

  Rect columnSlot(int c) => Rect.fromLTWH(colX(c), tableauY, cardW, cardH);

  /// Шаги веера для колонки с учётом сжатия, чтобы колонка влезла.
  (double, double) steps(GameState s, int c) {
    final n = s.columns[c].length;
    if (n <= 1) return (downStep, upStep);
    final down = math.min(s.faceDown[c], n - 1);
    final up = n - 1 - down;
    final avail = bottomY - tableauY - cardH;
    final need = down * downStep + up * upStep;
    if (need <= avail || need == 0) return (downStep, upStep);
    final k = avail / need;
    // Закрытые карты сжимаем сильнее открытых.
    final d = downStep * math.max(0.45, k);
    final remaining = avail - down * d;
    final u = up == 0 ? upStep : math.max(cardH * 0.12, remaining / up);
    return (d, u);
  }

  Offset cardPos(GameState s, int c, int i) {
    final (d, u) = steps(s, c);
    final down = s.faceDown[c];
    var y = tableauY;
    for (var k = 0; k < i; k++) {
      y += k < down ? d : u;
    }
    return Offset(colX(c), y);
  }

  Offset stockPos(int depth) => stockRect.topLeft + Offset(depth * cardW * 0.025, depth * cardW * 0.04);

  Offset foundationPos(int slot, int i) => foundationRects[slot].topLeft + Offset(i * 0.12, i * 0.2);

  /// Цели для всех 52 карт.
  List<CardTarget> targets(GameState s) {
    final out = List<CardTarget?>.filled(52, null);
    for (var i = 0; i < s.stock.length; i++) {
      // stock[0] раздаётся первым — он лежит сверху.
      final depth = s.stock.length - 1 - i;
      out[s.stock[i]] = CardTarget(stockPos(depth), false, 10 + depth, -1, i);
    }
    for (var c = 0; c < kColumns; c++) {
      final col = s.columns[c];
      for (var i = 0; i < col.length; i++) {
        out[col[i]] = CardTarget(cardPos(s, c, i), i >= s.faceDown[c], 100 + c * 60 + i, c, i);
      }
    }
    for (final suit in s.foundations) {
      for (var r = 1; r <= 13; r++) {
        final card = makeCard(suit, r);
        // Король сверху.
        out[card] = CardTarget(foundationPos(suit, 13 - r), true, 1000 + suit * 20 + r, -1, 13 - r);
      }
    }
    return [for (final t in out) t!];
  }
}
