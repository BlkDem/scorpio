import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scorpion/main.dart';
import 'package:scorpion/state/game_controller.dart';
import 'package:scorpion/state/settings.dart';
import 'package:scorpion/state/sfx.dart';
import 'package:scorpion/state/stats.dart';
import 'package:scorpion/ui/board/board_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> frames(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('drag, tap, undo and invalid drop', (tester) async {
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    tester.view.devicePixelRatio = 2;
    SharedPreferences.setMockInitialValues({'solvable': false});
    final prefs = await SharedPreferences.getInstance();
    final settings = await Settings.load(prefs);
    final stats = await Stats.load(prefs);
    final c = GameController(settings: settings, stats: stats, sfx: Sfx(settings), prefs: prefs);
    await c.newGame(seed: 5);
    await tester.pumpWidget(ScorpionApp(controller: c, settings: settings, stats: stats));
    await frames(tester, 3500);
    final board = tester.state<BoardViewState>(find.byType(BoardView));
    final l = board.layout!;

    Offset grip(int col, int idx) => board.sprites[c.state.columns[col][idx]].rest + Offset(l.cardW / 2, 6);
    Offset topCardCenter(int col) => board.sprites[c.state.columns[col].last].rest + Offset(l.cardW / 2, l.cardH / 2);

    // 1. Перетаскивание: 3♦ (колонка 6, индекс 1) на 4♦ (колонка 4).
    final card = c.state.columns[5][1];
    final from = grip(5, 1);
    final to = topCardCenter(3) + Offset(0, l.upStep);
    final g = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 1; i <= 12; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 12)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await frames(tester, 200);
    await g.up();
    await frames(tester, 800);
    expect(c.state.columns[3].contains(card), isTrue, reason: 'drag move');
    expect(c.moves, 1);

    // 2. Нажатие: 8♦ (колонка 3, индекс 4) сам уходит на 9♦.
    final card2 = c.state.columns[2][4];
    await tester.tapAt(grip(2, 4));
    await frames(tester, 800);
    expect(c.state.columns[4].contains(card2), isTrue, reason: 'tap move');
    expect(c.moves, 2);

    // 3. Отмена.
    c.undo();
    await frames(tester, 600);
    expect(c.state.columns[2].contains(card2), isTrue, reason: 'undo');

    // 4. Бросок в пустоту — карта возвращается, хода нет.
    final before = c.moves;
    final src = c.state.columns[6].length - 1;
    final p0 = grip(6, src);
    final g2 = await tester.startGesture(p0);
    for (var i = 1; i <= 8; i++) {
      await g2.moveTo(p0 + Offset(-20.0 * i, 40.0 * i));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g2.up();
    await frames(tester, 800);
    expect(c.moves, before);
    final sp = board.sprites[c.state.columns[6].last];
    expect((sp.pos - sp.rest).distance < 1, isTrue, reason: 'card returned');

    // 5. Резерв по нажатию.
    await tester.tapAt(l.stockRect.center);
    await frames(tester, 1200);
    expect(c.state.stock, isEmpty);

    c.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
