import 'cards.dart';

const int kColumns = 7;

/// Ход: перенос карты (вместе со всеми картами поверх неё) или раздача резерва.
class Move {
  final int from;
  final int index;
  final int to;

  const Move.stack(this.from, this.index, this.to);
  const Move.deal() : from = -1, index = 0, to = -1;

  bool get isDeal => from < 0;

  Map<String, dynamic> toJson() => {'f': from, 'i': index, 't': to};

  factory Move.fromJson(Map<String, dynamic> j) =>
      (j['f'] as int) < 0 ? const Move.deal() : Move.stack(j['f'] as int, j['i'] as int, j['t'] as int);

  @override
  bool operator ==(Object other) => other is Move && other.from == from && other.index == index && other.to == to;

  @override
  int get hashCode => Object.hash(from, index, to);

  @override
  String toString() => isDeal ? 'Deal' : 'Move($from[$index] -> $to)';
}

/// Детерминированный ГПСЧ (Park–Miller), одинаковый на всех платформах.
class DealRandom {
  int _state;
  DealRandom(int seed) : _state = (seed % 2147483646) + 1;

  int next() {
    _state = (_state * 48271) % 2147483647;
    return _state;
  }

  int nextInt(int max) => next() % max;
}

/// Полное состояние партии.
class GameState {
  final List<List<int>> columns;

  /// Количество закрытых карт в основании каждой колонки.
  final List<int> faceDown;

  /// Резерв (3 карты), раздаётся один раз.
  final List<int> stock;

  /// Масти, собранные полностью (K..A), в порядке сборки.
  final List<int> foundations;

  GameState({required this.columns, required this.faceDown, required this.stock, required this.foundations});

  /// Классическая раздача: 7 колонок по 7 карт, в первых четырёх по 3 закрытые.
  factory GameState.deal(int seed) {
    final deck = List<int>.generate(52, (i) => i);
    final rnd = DealRandom(seed);
    for (var i = deck.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final t = deck[i];
      deck[i] = deck[j];
      deck[j] = t;
    }
    final columns = List.generate(kColumns, (_) => <int>[]);
    var k = 0;
    for (var row = 0; row < 7; row++) {
      for (var c = 0; c < kColumns; c++) {
        columns[c].add(deck[k++]);
      }
    }
    return GameState(columns: columns, faceDown: [3, 3, 3, 3, 0, 0, 0], stock: deck.sublist(49), foundations: []);
  }

  GameState copy() => GameState(
    columns: [for (final c in columns) List<int>.of(c)],
    faceDown: List<int>.of(faceDown),
    stock: List<int>.of(stock),
    foundations: List<int>.of(foundations),
  );

  bool get isWon => foundations.length == 4;

  bool isFaceUp(int col, int index) => index >= faceDown[col];

  /// Ищет карту на столе. Возвращает (колонка, индекс) или null.
  (int, int)? locate(int card) {
    for (var c = 0; c < kColumns; c++) {
      final i = columns[c].indexOf(card);
      if (i >= 0) return (c, i);
    }
    return null;
  }

  bool canMove(int from, int index, int to) {
    if (from < 0 || to < 0 || from == to) return false;
    final src = columns[from];
    if (index < 0 || index >= src.length || index < faceDown[from]) return false;
    final card = src[index];
    final dst = columns[to];
    if (dst.isEmpty) return isKing(card);
    final top = dst.last;
    return suitOf(top) == suitOf(card) && rankOf(top) == rankOf(card) + 1;
  }

  bool get canDeal => stock.isNotEmpty;

  /// Применяет ход. Возвращает номер колонки, где открылась карта (или -1).
  int apply(Move m) {
    if (m.isDeal) {
      for (var i = 0; i < stock.length; i++) {
        columns[i].add(stock[i]);
      }
      stock.clear();
      return -1;
    }
    final src = columns[m.from];
    final moving = src.sublist(m.index);
    src.removeRange(m.index, src.length);
    columns[m.to].addAll(moving);
    if (src.isNotEmpty && faceDown[m.from] >= src.length) {
      faceDown[m.from] = src.length - 1;
      return m.from;
    }
    if (src.isEmpty) faceDown[m.from] = 0;
    return -1;
  }

  /// Колонка, в конце которой лежит полная масть K..A (все карты открыты), или -1.
  int findCompleted() {
    for (var c = 0; c < kColumns; c++) {
      final col = columns[c];
      if (col.length < 13) continue;
      final start = col.length - 13;
      if (start < faceDown[c]) continue;
      final k = col[start];
      if (!isKing(k)) continue;
      var ok = true;
      for (var i = 1; i < 13; i++) {
        if (col[start + i] != k - i) {
          ok = false;
          break;
        }
      }
      if (ok) return c;
    }
    return -1;
  }

  /// Убирает собранную масть из колонки. Возвращает убранные карты (K..A)
  /// и номер колонки, где открылась карта (или -1).
  (List<int>, int) collect(int col) {
    final src = columns[col];
    final cards = src.sublist(src.length - 13);
    src.removeRange(src.length - 13, src.length);
    foundations.add(suitOf(cards.first));
    var flipped = -1;
    if (src.isNotEmpty && faceDown[col] >= src.length) {
      faceDown[col] = src.length - 1;
      flipped = col;
    }
    if (src.isEmpty) faceDown[col] = 0;
    return (cards, flipped);
  }

  /// Все разумные ходы (без бессмысленного переноса короля из пустой колонки в пустую).
  List<Move> usefulMoves() {
    final moves = <Move>[];
    // Позиции открытых карт.
    final posCol = List<int>.filled(52, -1);
    final posIdx = List<int>.filled(52, -1);
    var firstEmpty = -1;
    for (var c = 0; c < kColumns; c++) {
      final col = columns[c];
      if (col.isEmpty && firstEmpty < 0) firstEmpty = c;
      for (var i = faceDown[c]; i < col.length; i++) {
        posCol[col[i]] = c;
        posIdx[col[i]] = i;
      }
    }
    for (var c = 0; c < kColumns; c++) {
      final col = columns[c];
      if (col.isEmpty) continue;
      final top = col.last;
      if (rankOf(top) == 1) continue;
      final need = top - 1; // та же масть, на единицу младше
      final pc = posCol[need];
      if (pc < 0 || pc == c) continue;
      moves.add(Move.stack(pc, posIdx[need], c));
    }
    // Куда ставить короля: пустые колонки равноправны, кроме того, что до
    // раздачи резерва колонки 1–3 получат ещё по карте.
    final empties = <int>[];
    if (firstEmpty >= 0) {
      if (stock.isEmpty) {
        empties.add(firstEmpty);
      } else {
        for (final range in const [(0, 3), (3, kColumns)]) {
          for (var c = range.$1; c < range.$2; c++) {
            if (columns[c].isEmpty) {
              empties.add(c);
              break;
            }
          }
        }
      }
    }
    for (final e in empties) {
      for (var s = 0; s < 4; s++) {
        final k = makeCard(s, 13);
        final pc = posCol[k];
        if (pc < 0) continue;
        if (posIdx[k] == 0 && (stock.isEmpty || (pc < 3) == (e < 3))) continue;
        moves.add(Move.stack(pc, posIdx[k], e));
      }
    }
    if (stock.isNotEmpty) moves.add(const Move.deal());
    return moves;
  }

  /// Быстрый хеш позиции для решателя (с учётом симметрии колонок).
  int hashKey() {
    final hs = List<int>.filled(kColumns, 0);
    for (var c = 0; c < kColumns; c++) {
      var h = 17 + faceDown[c] * 31;
      for (final x in columns[c]) {
        h = ((h * 1000003) ^ (x + 1)) & 0xFFFFFFFFFFFFF;
      }
      hs[c] = h;
    }
    if (stock.isEmpty) {
      hs.sort();
    } else {
      // До раздачи резерва равноправны только колонки 4..7.
      final tail = hs.sublist(3)..sort();
      hs.setRange(3, kColumns, tail);
    }
    var r = stock.isEmpty ? 7 : 11;
    for (final h in hs) {
      r = ((r * 31) ^ h) & 0xFFFFFFFFFFFFF;
    }
    return r;
  }

  /// Канонический ключ позиции для поиска.
  String key() {
    final parts = <String>[];
    for (var c = 0; c < kColumns; c++) {
      parts.add(String.fromCharCodes([65 + faceDown[c], ...columns[c].map((x) => 48 + x)]));
    }
    if (stock.isEmpty) {
      // После раздачи резерва колонки равноправны.
      parts.sort();
      return parts.join('|');
    }
    return '${parts.join('|')}#';
  }

  Map<String, dynamic> toJson() => {
    'columns': columns,
    'faceDown': faceDown,
    'stock': stock,
    'foundations': foundations,
  };

  factory GameState.fromJson(Map<String, dynamic> j) => GameState(
    columns: [for (final c in j['columns'] as List) List<int>.from(c as List)],
    faceDown: List<int>.from(j['faceDown'] as List),
    stock: List<int>.from(j['stock'] as List),
    foundations: List<int>.from(j['foundations'] as List),
  );
}
