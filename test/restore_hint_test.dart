import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scorpion/main.dart';
import 'package:scorpion/state/game_controller.dart';
import 'package:scorpion/state/settings.dart';
import 'package:scorpion/state/sfx.dart';
import 'package:scorpion/state/stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> frames(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('hint works after restoring a saved game', (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    SharedPreferences.setMockInitialValues({'solvable': false});
    var prefs = await SharedPreferences.getInstance();
    // Первая сессия: сыграли ход и «закрыли» приложение.
    final s1 = await Settings.load(prefs);
    final c1 = GameController(settings: s1, stats: await Stats.load(prefs), sfx: Sfx(s1), prefs: prefs);
    await c1.newGame(seed: 770870);
    final m = c1.state.usefulMoves().firstWhere((m) => !m.isDeal);
    c1.tryMove(m.from, m.index, m.to);
    final saved = prefs.getString('game')!;
    c1.dispose();

    // Вторая сессия.
    SharedPreferences.setMockInitialValues({'solvable': false, 'game': saved});
    prefs = await SharedPreferences.getInstance();
    final settings = await Settings.load(prefs);
    final stats = await Stats.load(prefs);
    final c = GameController(settings: settings, stats: stats, sfx: Sfx(settings), prefs: prefs);
    await tester.pumpWidget(ScorpionApp(controller: c, settings: settings, stats: stats));
    await c.init();
    await frames(tester, 1000);
    expect(c.moves, 1);
    expect(c.ready, isTrue);

    await tester.tap(find.text('Подсказка'));
    await tester.pump();
    // Решатель работает в изоляте — даём ему время.
    for (var i = 0; i < 40 && c.hints == 0; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(c.hints, 1, reason: 'hint delivered');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('→'), findsOneWidget);
    // ignore: avoid_print
    print('toast: ${(find.textContaining('→').evaluate().first.widget as Text).data}');
    c.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
