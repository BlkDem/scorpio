import 'package:flutter/foundation.dart';

import 'cards.dart';
import 'game_state.dart';

/// Результат поиска решения.
class SolveResult {
  /// Последовательность ходов до победы (null — решение не найдено).
  final List<Move>? solution;

  /// true — перебор завершён полностью (если решения нет, позиция проиграна).
  final bool exhaustive;
  final int nodes;

  const SolveResult(this.solution, this.exhaustive, this.nodes);

  bool get solved => solution != null;
}

/// Решатель «Скорпиона»: поиск в глубину с таблицей уже виденных позиций
/// и эвристическим порядком ходов. Ходы в «Скорпионе» необратимы (каждый
/// ход увеличивает число правильных связок или ставит короля в основание),
/// поэтому дерево конечно, а циклов нет.
class ScorpionSolver {
  final int nodeLimit;
  final Set<int> _seen = {};
  int _nodes = 0;
  bool _aborted = false;

  ScorpionSolver({this.nodeLimit = 60000});

  SolveResult solve(GameState start) {
    final s = start.copy();
    collectAll(s);
    final path = <Move>[];
    final ok = _dfs(s, path);
    return SolveResult(ok ? path : null, !_aborted, _nodes);
  }

  static void collectAll(GameState s) {
    int c;
    while ((c = s.findCompleted()) >= 0) {
      s.collect(c);
    }
  }

  bool _dfs(GameState s, List<Move> path) {
    if (s.isWon) return true;
    if (++_nodes > nodeLimit) {
      _aborted = true;
      return false;
    }
    if (!_seen.add(s.hashKey())) return false;

    final moves = s.usefulMoves();
    final children = <(Move, GameState, int)>[];
    for (final m in moves) {
      final n = s.copy();
      n.apply(m);
      collectAll(n);
      if (n.isWon) {
        path.add(m);
        return true;
      }
      children.add((m, n, evaluate(n) + (m.isDeal ? dealBias : 0)));
    }
    children.sort((a, b) => b.$3.compareTo(a.$3));
    for (final c in children) {
      path.add(c.$1);
      if (_dfs(c.$2, path)) return true;
      path.removeLast();
      if (_aborted) return false;
    }
    return false;
  }

  static int dealBias = -30;

  /// Оценка позиции: чем больше — тем ближе к победе.
  static int evaluate(GameState s) {
    var score = s.foundations.length * 400;
    for (var c = 0; c < kColumns; c++) {
      final col = s.columns[c];
      final down = s.faceDown[c];
      score -= down * 25;
      if (col.isEmpty) {
        score += 15;
        continue;
      }
      if (isKing(col[0]) && down == 0) score += 12;
      for (var i = 1; i < col.length; i++) {
        final u = col[i];
        if (i - 1 >= down && isLink(col[i - 1], u)) {
          score += 10;
        }
        // Карта лежит выше своей «цели» в той же колонке — тяжёлый узел.
        if (rankOf(u) < 13) {
          final target = u + 1;
          for (var j = 0; j < i - 1; j++) {
            if (col[j] == target) {
              score -= 14;
              break;
            }
          }
        }
      }
    }
    return score;
  }

  /// Кандидаты для ветвления в порядке приоритета.
  static List<Move> orderedCandidates(GameState s) {
    final moves = s.usefulMoves();
    Move? deal;
    final scored = <(Move, int)>[];
    for (final m in moves) {
      if (m.isDeal) {
        deal = m;
      } else {
        scored.add((m, scoreMove(s, m)));
      }
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final e in scored) e.$1, ?deal];
  }

  /// Эвристическая оценка хода (для порядка перебора и запасной подсказки).
  static int scoreMove(GameState s, Move m) {
    if (m.isDeal) return -50;
    var score = 0;
    final down = s.faceDown[m.from];
    final card = s.columns[m.from][m.index];
    if (m.index == down && down > 0) score += 120 + down * 5; // открывает карту
    if (m.index == 0) score += 70; // освобождает колонку
    if (isKing(card)) score += 20;
    // Чем длиннее получается цепочка на месте назначения — тем лучше.
    final dst = s.columns[m.to];
    var run = 0;
    for (var i = dst.length - 1; i > 0; i--) {
      if (isLink(dst[i - 1], dst[i]) && i - 1 >= s.faceDown[m.to]) {
        run++;
      } else {
        break;
      }
    }
    score += run * 2;
    // Чем меньше «мусора» переезжает вместе с картой — тем аккуратнее.
    final carried = s.columns[m.from].length - m.index - 1;
    var orderedAbove = 0;
    for (var i = m.index + 1; i < s.columns[m.from].length; i++) {
      if (isLink(s.columns[m.from][i - 1], s.columns[m.from][i])) {
        orderedAbove++;
      } else {
        break;
      }
    }
    score -= (carried - orderedAbove);
    return score;
  }
}

/// Запуск решателя в фоне (на вебе — в основном потоке).
Future<SolveResult> solveInBackground(GameState s, {int nodeLimit = 60000}) {
  return compute(_solveEntry, (s.toJson(), nodeLimit));
}

SolveResult _solveEntry((Map<String, dynamic>, int) args) {
  final s = GameState.fromJson(args.$1);
  return ScorpionSolver(nodeLimit: args.$2).solve(s);
}

/// Поиск номера решаемой раскладки, начиная с [startSeed].
Future<int> findSolvableSeed(int startSeed) {
  return compute(_findSolvableEntry, startSeed);
}

int _findSolvableEntry(int startSeed) {
  var seed = startSeed;
  for (var attempt = 0; attempt < 3000; attempt++) {
    final r = ScorpionSolver(nodeLimit: 6000).solve(GameState.deal(seed));
    if (r.solved) return seed;
    seed = seed % 999999 + 1;
  }
  return startSeed;
}
