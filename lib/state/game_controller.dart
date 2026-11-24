import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/cards.dart';
import '../game/game_state.dart';
import '../game/solver.dart';
import 'settings.dart';
import 'sfx.dart';
import 'stats.dart';

/// Что произошло на столе — от этого зависит характер анимации.
enum ChangeKind { none, newDeal, move, stockDeal, collect, undo, restore }

class BoardEvent {
  final ChangeKind kind;

  /// Перемещённые карты (для хода — стопка, для сбора — K..A).
  final List<int> cards;

  /// Ход сделан перетаскиванием (карты уже рядом с целью).
  final bool dragged;

  /// Колонка, где открылась карта, или -1.
  final int flippedColumn;

  const BoardEvent(this.kind, {this.cards = const [], this.dragged = false, this.flippedColumn = -1});

  static const none = BoardEvent(ChangeKind.none);
}

enum HintKind { move, deal, noMoves }

class HintResult {
  final HintKind kind;
  final Move? move;

  /// true — ход ведёт к победе; false — позиция проиграна; null — неизвестно.
  final bool? winnable;

  const HintResult(this.kind, {this.move, this.winnable});
}

class _Snapshot {
  final GameState state;
  final int moves;
  _Snapshot(this.state, this.moves);
}

class GameController extends ChangeNotifier {
  final Settings settings;
  final Stats stats;
  final Sfx sfx;
  final SharedPreferences prefs;

  GameController({required this.settings, required this.stats, required this.sfx, required this.prefs});

  GameState state = GameState.deal(1);
  int dealNumber = 1;
  int moves = 0;
  int hints = 0;
  int undos = 0;
  bool started = false;
  bool won = false;
  bool preparing = false;

  /// Партия загружена (до этого стол пуст, колода лежит в резерве).
  bool ready = false;
  RecordNews? lastNews;
  GameRecord? lastRecord;

  BoardEvent event = BoardEvent.none;
  int version = 0;

  final List<_Snapshot> _undo = [];
  Timer? _collectTimer;

  // Время партии.
  int _elapsedBefore = 0;
  DateTime? _runningSince;
  bool _paused = false;

  // Кэш решения для подсказок: хеш позиции -> ход.
  final Map<int, Move> _solutionByKey = {};
  bool hintBusy = false;

  /// Колбэки для эффектов, которые не выражаются состоянием.
  void Function(HintResult)? onHint;
  void Function()? onWin;
  void Function(int card)? onReject;

  int get elapsedSeconds {
    var ms = _elapsedBefore;
    if (_runningSince != null) ms += DateTime.now().difference(_runningSince!).inMilliseconds;
    return ms ~/ 1000;
  }

  bool get canUndo => _undo.isNotEmpty && !won;
  bool get hasPendingCollect => _collectTimer != null;

  /// Нет полезных ходов и резерв пуст.
  bool get isStuck => !won && !hasPendingCollect && state.findCompleted() < 0 && state.usefulMoves().isEmpty;

  // ---------------------------------------------------------------- Жизненный цикл

  Future<void> init() async {
    final raw = prefs.getString('game');
    if (raw != null) {
      try {
        _restore(jsonDecode(raw) as Map<String, dynamic>);
        if (!won) {
          ready = true;
          _emit(const BoardEvent(ChangeKind.restore));
          return;
        }
        won = false;
        started = false;
      } catch (_) {}
    }
    await newGame();
  }

  void pauseClock() {
    _paused = true;
    _stopClock();
  }

  void resumeClock() {
    _paused = false;
    if (started && !won) _startClock();
  }

  void _startClock() {
    if (_paused) return;
    _runningSince ??= DateTime.now();
  }

  void _stopClock() {
    if (_runningSince != null) {
      _elapsedBefore += DateTime.now().difference(_runningSince!).inMilliseconds;
      _runningSince = null;
    }
  }

  // ---------------------------------------------------------------- Партии

  void _abandonIfNeeded() {
    if (started && !won) {
      _stopClock();
      stats.record(
        GameRecord(
          deal: dealNumber,
          won: false,
          seconds: elapsedSeconds,
          moves: moves,
          hints: hints,
          undos: undos,
          at: DateTime.now(),
        ),
      );
    }
  }

  Future<void> newGame({int? seed}) async {
    if (preparing) return;
    _flushCollect();
    _abandonIfNeeded();
    var s = seed ?? (math.Random().nextInt(999999) + 1);
    if (seed == null && settings.solvableOnly) {
      preparing = true;
      notifyListeners();
      try {
        await _letFramePaint();
        s = await findSolvableSeed(s);
      } finally {
        preparing = false;
      }
    }
    _startDeal(s);
  }

  void restart() {
    _flushCollect();
    _abandonIfNeeded();
    _startDeal(dealNumber);
  }

  void _startDeal(int seed) {
    ready = true;
    dealNumber = seed;
    state = GameState.deal(seed);
    moves = 0;
    hints = 0;
    undos = 0;
    started = false;
    won = false;
    lastNews = null;
    lastRecord = null;
    _elapsedBefore = 0;
    _runningSince = null;
    _undo.clear();
    _solutionByKey.clear();
    sfx.play(Sound.shuffle);
    _emit(const BoardEvent(ChangeKind.newDeal));
  }

  // ---------------------------------------------------------------- Ходы

  bool canMove(int from, int index, int to) => !won && state.canMove(from, index, to);

  /// Куда можно отправить карту по нажатию.
  int autoDestination(int col, int index) {
    if (index < state.faceDown[col]) return -1;
    final card = state.columns[col][index];
    if (isKing(card)) {
      if (index == 0) return -1;
      for (var c = 0; c < kColumns; c++) {
        if (state.columns[c].isEmpty) return c;
      }
      return -1;
    }
    for (var c = 0; c < kColumns; c++) {
      if (c != col && state.canMove(col, index, c)) return c;
    }
    return -1;
  }

  bool tryMove(int from, int index, int to, {bool dragged = false}) {
    _flushCollect();
    if (!canMove(from, index, to)) return false;
    _pushUndo();
    final cards = state.columns[from].sublist(index);
    final flipped = state.apply(Move.stack(from, index, to));
    moves++;
    _markStarted();
    sfx.play(dragged ? Sound.place : Sound.slide);
    sfx.tick();
    if (flipped >= 0) {
      Future.delayed(const Duration(milliseconds: 160), () => sfx.play(Sound.flip, volume: 0.8));
    }
    _emit(BoardEvent(ChangeKind.move, cards: cards, dragged: dragged, flippedColumn: flipped));
    _scheduleCollect();
    return true;
  }

  bool tapCard(int col, int index) {
    _flushCollect();
    if (won) return false;
    final dst = autoDestination(col, index);
    if (dst < 0) {
      final card = state.columns[col][index];
      onReject?.call(card);
      sfx.play(Sound.error, volume: 0.6);
      sfx.light();
      return false;
    }
    return tryMove(col, index, dst);
  }

  bool dealStock() {
    _flushCollect();
    if (won || !state.canDeal) return false;
    _pushUndo();
    final cards = List<int>.of(state.stock);
    state.apply(const Move.deal());
    moves++;
    _markStarted();
    for (var i = 0; i < cards.length; i++) {
      Future.delayed(Duration(milliseconds: 60 + i * 120), () => sfx.play(Sound.slide, volume: 0.8));
    }
    sfx.medium();
    _emit(BoardEvent(ChangeKind.stockDeal, cards: cards));
    _scheduleCollect();
    return true;
  }

  void undo() {
    _flushCollect();
    if (_undo.isEmpty || won) return;
    final snap = _undo.removeLast();
    state = snap.state;
    moves = snap.moves;
    undos++;
    sfx.play(Sound.slide, volume: 0.7);
    sfx.tick();
    _emit(const BoardEvent(ChangeKind.undo));
  }

  void _pushUndo() {
    _undo.add(_Snapshot(state.copy(), moves));
    if (_undo.length > 400) _undo.removeAt(0);
  }

  void _markStarted() {
    if (!started) started = true;
    _startClock();
  }

  // ---------------------------------------------------------------- Сбор мастей

  void _scheduleCollect() {
    if (state.findCompleted() < 0) return;
    _collectTimer?.cancel();
    _collectTimer = Timer(const Duration(milliseconds: 430), () {
      _collectTimer = null;
      _collectNow();
    });
  }

  void _flushCollect() {
    if (_collectTimer != null) {
      _collectTimer!.cancel();
      _collectTimer = null;
      _collectNow();
    }
  }

  void _collectNow() {
    final c = state.findCompleted();
    if (c < 0) return;
    final (cards, flipped) = state.collect(c);
    sfx.play(Sound.collect);
    sfx.medium();
    _emit(BoardEvent(ChangeKind.collect, cards: cards.reversed.toList(), flippedColumn: flipped));
    if (state.findCompleted() >= 0) {
      _scheduleCollect();
    } else if (state.isWon) {
      _win();
    }
  }

  void _win() {
    won = true;
    _stopClock();
    final rec = GameRecord(
      deal: dealNumber,
      won: true,
      seconds: math.max(1, elapsedSeconds),
      moves: moves,
      hints: hints,
      undos: undos,
      at: DateTime.now(),
    );
    lastRecord = rec;
    lastNews = stats.record(rec);
    _save();
    // Ждём, пока последняя масть долетит до «дома».
    Future.delayed(const Duration(milliseconds: 1250), () {
      sfx.play(Sound.win);
      sfx.heavy();
      onWin?.call();
      notifyListeners();
    });
  }

  /// На вебе `compute` выполняется в основном потоке: сначала даём кадру
  /// с индикатором («Тасуем колоду…», спиннер подсказки) отрисоваться.
  static Future<void> _letFramePaint() =>
      kIsWeb ? Future<void>.delayed(const Duration(milliseconds: 40)) : Future<void>.value();

  // ---------------------------------------------------------------- Подсказки

  Future<HintResult?> hint() async {
    _flushCollect();
    if (won || hintBusy || preparing) return null;
    final key = state.hashKey();
    final cached = _solutionByKey[key];
    if (cached != null) {
      return _deliverHint(HintResult(cached.isDeal ? HintKind.deal : HintKind.move, move: cached, winnable: true));
    }
    hintBusy = true;
    notifyListeners();
    final v = version;
    SolveResult r;
    try {
      await _letFramePaint();
      // На вебе поиск идёт в основном потоке и медленнее — ограничиваем его сильнее.
      r = await solveInBackground(state, nodeLimit: kIsWeb ? 40000 : 120000);
    } catch (_) {
      r = const SolveResult(null, false, 0);
    }
    hintBusy = false;
    if (v != version) {
      notifyListeners();
      return null; // Позиция изменилась, пока думали.
    }
    if (r.solved && r.solution!.isNotEmpty) {
      // Запоминаем всю линию решения.
      final sim = state.copy();
      for (final m in r.solution!) {
        _solutionByKey[sim.hashKey()] = m;
        sim.apply(m);
        ScorpionSolver.collectAll(sim);
      }
      final m = r.solution!.first;
      return _deliverHint(HintResult(m.isDeal ? HintKind.deal : HintKind.move, move: m, winnable: true));
    }
    final candidates = ScorpionSolver.orderedCandidates(state);
    if (candidates.isEmpty) {
      return _deliverHint(const HintResult(HintKind.noMoves, winnable: false));
    }
    final m = candidates.first;
    return _deliverHint(
      HintResult(m.isDeal ? HintKind.deal : HintKind.move, move: m, winnable: r.exhaustive ? false : null),
    );
  }

  HintResult _deliverHint(HintResult h) {
    hints++;
    if (h.kind != HintKind.noMoves) sfx.play(Sound.hint, volume: 0.7);
    _save();
    notifyListeners();
    onHint?.call(h);
    return h;
  }

  // ---------------------------------------------------------------- Служебное

  void _emit(BoardEvent e) {
    event = e;
    version++;
    _save();
    notifyListeners();
  }

  void _save() {
    final j = {
      'deal': dealNumber,
      'state': state.toJson(),
      'moves': moves,
      'hints': hints,
      'undos': undos,
      'started': started,
      'won': won,
      'elapsed':
          _elapsedBefore + (_runningSince == null ? 0 : DateTime.now().difference(_runningSince!).inMilliseconds),
      'undo': [
        for (final s in _undo.length > 150 ? _undo.sublist(_undo.length - 150) : _undo)
          {'s': s.state.toJson(), 'm': s.moves},
      ],
    };
    prefs.setString('game', jsonEncode(j));
  }

  void _restore(Map<String, dynamic> j) {
    dealNumber = j['deal'] as int;
    state = GameState.fromJson(j['state'] as Map<String, dynamic>);
    ScorpionSolver.collectAll(state);
    moves = j['moves'] as int;
    hints = j['hints'] as int? ?? 0;
    undos = j['undos'] as int? ?? 0;
    started = j['started'] as bool;
    won = j['won'] as bool? ?? false;
    _elapsedBefore = j['elapsed'] as int? ?? 0;
    _undo
      ..clear()
      ..addAll([
        for (final u in (j['undo'] as List? ?? []))
          _Snapshot(GameState.fromJson((u as Map<String, dynamic>)['s'] as Map<String, dynamic>), u['m'] as int),
      ]);
    if (started && !won) _startClock();
  }

  @override
  void dispose() {
    _collectTimer?.cancel();
    super.dispose();
  }
}
