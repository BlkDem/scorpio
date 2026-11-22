import 'package:flutter_test/flutter_test.dart';
import 'package:scorpion/game/cards.dart';
import 'package:scorpion/game/game_state.dart';
import 'package:scorpion/game/solver.dart';

GameState make(List<List<int>> cols, {List<int>? down, List<int> stock = const []}) => GameState(
  columns: [for (final c in cols) List<int>.of(c)],
  faceDown: down ?? List.filled(7, 0),
  stock: List.of(stock),
  foundations: [],
);

void main() {
  test('moves only onto next higher card of the same suit', () {
    final s = make([
      [makeCard(kHearts, 9)],
      [makeCard(kHearts, 8), makeCard(kClubs, 2)],
      [makeCard(kSpades, 8)],
      [],
      [],
      [],
      [],
    ]);
    expect(s.canMove(1, 0, 0), isTrue); // 8♥ (с 2♣ сверху) на 9♥
    expect(s.canMove(2, 0, 0), isFalse); // 8♠ на 9♥ нельзя
    expect(s.canMove(1, 1, 3), isFalse); // 2♣ в пустую колонку нельзя
    s.apply(const Move.stack(1, 0, 0));
    expect(s.columns[0].length, 3);
    expect(s.columns[1], isEmpty);
  });

  test('only kings go to empty columns, face-down cards flip', () {
    final s = make(
      [
        [makeCard(kClubs, 5), makeCard(kSpades, 13)],
        [],
        [],
        [],
        [],
        [],
        [],
      ],
      down: [1, 0, 0, 0, 0, 0, 0],
    );
    expect(s.canMove(0, 1, 1), isTrue);
    final flipped = s.apply(const Move.stack(0, 1, 1));
    expect(flipped, 0);
    expect(s.faceDown[0], 0);
  });

  test('complete suit is collected and win detected', () {
    final suitCards = [for (var r = 13; r >= 1; r--) makeCard(kDiamonds, r)];
    final s = make([suitCards, [], [], [], [], [], []]);
    expect(s.findCompleted(), 0);
    final (cards, _) = s.collect(0);
    expect(cards.length, 13);
    expect(s.foundations, [kDiamonds]);
  });

  test('stock deals one card to each of the first three columns', () {
    final s = GameState.deal(7);
    final tops = [for (var c = 0; c < 3; c++) s.columns[c].length];
    final stock = List.of(s.stock);
    s.apply(const Move.deal());
    for (var c = 0; c < 3; c++) {
      expect(s.columns[c].length, tops[c] + 1);
      expect(s.columns[c].last, stock[c]);
    }
    expect(s.canDeal, isFalse);
  });

  test('json roundtrip and hash are stable', () {
    final s = GameState.deal(99);
    final j = GameState.fromJson(s.toJson());
    expect(j.hashKey(), s.hashKey());
  });

  test('deals are deterministic', () {
    expect(GameState.deal(123456).toJson(), GameState.deal(123456).toJson());
    expect(GameState.deal(1).toJson(), isNot(GameState.deal(2).toJson()));
  });

  test('solver hint for a solvable deal leads to a win', () {
    var seed = 1;
    SolveResult r;
    do {
      r = ScorpionSolver(nodeLimit: 6000).solve(GameState.deal(seed++));
    } while (!r.solved);
    expect(r.solution, isNotEmpty);
  });
}
