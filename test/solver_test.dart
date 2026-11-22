import 'package:flutter_test/flutter_test.dart';
import 'package:scorpion/game/game_state.dart';
import 'package:scorpion/game/solver.dart';

void main() {
  test('solutions are valid and solver is fast', () {
    var solved = 0, exhaustiveFail = 0, aborted = 0;
    var maxNodes = 0;
    final sw = Stopwatch()..start();
    const n = 200;
    for (var seed = 1; seed <= n; seed++) {
      final s = GameState.deal(seed);
      final r = ScorpionSolver(nodeLimit: 6000).solve(s);
      if (r.nodes > maxNodes) maxNodes = r.nodes;
      if (r.solved) {
        solved++;
        // Проверяем решение честным проигрыванием.
        final g = s.copy();
        for (final m in r.solution!) {
          if (m.isDeal) {
            expect(g.canDeal, isTrue);
          } else {
            expect(g.canMove(m.from, m.index, m.to), isTrue, reason: 'seed $seed $m');
          }
          g.apply(m);
          ScorpionSolver.collectAll(g);
        }
        expect(g.isWon, isTrue);
      } else if (r.exhaustive) {
        exhaustiveFail++;
      } else {
        aborted++;
      }
    }
    // ignore: avoid_print
    print(
      'solved $solved/$n, unsolvable(exh) $exhaustiveFail, aborted $aborted, maxNodes $maxNodes, ${sw.elapsedMilliseconds} ms',
    );
  });

  test('deal is classic', () {
    final s = GameState.deal(42);
    expect(s.columns.every((c) => c.length == 7), isTrue);
    expect(s.stock.length, 3);
    final all = {...s.stock, for (final c in s.columns) ...c};
    expect(all.length, 52);
  });
}
