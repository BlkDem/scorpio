import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Запись об одной завершённой (или брошенной) партии.
class GameRecord {
  final int deal;
  final bool won;
  final int seconds;
  final int moves;
  final int hints;
  final int undos;
  final DateTime at;

  const GameRecord({
    required this.deal,
    required this.won,
    required this.seconds,
    required this.moves,
    required this.hints,
    required this.undos,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
    'd': deal,
    'w': won,
    's': seconds,
    'm': moves,
    'h': hints,
    'u': undos,
    'a': at.millisecondsSinceEpoch,
  };

  factory GameRecord.fromJson(Map<String, dynamic> j) => GameRecord(
    deal: j['d'] as int,
    won: j['w'] as bool,
    seconds: j['s'] as int,
    moves: j['m'] as int,
    hints: (j['h'] as int?) ?? 0,
    undos: (j['u'] as int?) ?? 0,
    at: DateTime.fromMillisecondsSinceEpoch(j['a'] as int),
  );
}

/// Что нового случилось после записи победы — для поздравлений.
class RecordNews {
  final bool bestTime;
  final bool fewestMoves;
  final bool bestStreak;
  const RecordNews({this.bestTime = false, this.fewestMoves = false, this.bestStreak = false});
}

class Stats extends ChangeNotifier {
  final SharedPreferences _p;

  int played = 0;
  int won = 0;
  int streak = 0;
  int bestStreak = 0;
  int lossStreak = 0;
  int totalSeconds = 0;
  int wonSeconds = 0;
  int wonMoves = 0;
  int bestSeconds = 0;
  int fewestMoves = 0;
  int hintsUsed = 0;
  int noHintWins = 0;
  DateTime? firstGame;
  List<GameRecord> history = [];

  static const _historyLimit = 200;

  Stats._(this._p) {
    final raw = _p.getString('stats');
    if (raw != null) {
      try {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  static Future<Stats> load(SharedPreferences p) async => Stats._(p);

  double get winRate => played == 0 ? 0 : won / played;
  int get avgWinSeconds => won == 0 ? 0 : (wonSeconds / won).round();
  int get avgWinMoves => won == 0 ? 0 : (wonMoves / won).round();

  RecordNews record(GameRecord r) {
    var news = const RecordNews();
    played++;
    totalSeconds += r.seconds;
    hintsUsed += r.hints;
    firstGame ??= r.at;
    if (r.won) {
      won++;
      streak++;
      lossStreak = 0;
      wonSeconds += r.seconds;
      wonMoves += r.moves;
      if (r.hints == 0) noHintWins++;
      final bt = bestSeconds == 0 || r.seconds < bestSeconds;
      final fm = fewestMoves == 0 || r.moves < fewestMoves;
      final bs = streak > bestStreak;
      if (bt) bestSeconds = r.seconds;
      if (fm) fewestMoves = r.moves;
      if (bs) bestStreak = streak;
      news = RecordNews(bestTime: bt && won > 1, fewestMoves: fm && won > 1, bestStreak: bs && streak > 1);
    } else {
      streak = 0;
      lossStreak++;
    }
    history.insert(0, r);
    if (history.length > _historyLimit) history.removeRange(_historyLimit, history.length);
    _save();
    notifyListeners();
    return news;
  }

  void reset() {
    played = won = streak = bestStreak = lossStreak = 0;
    totalSeconds = wonSeconds = wonMoves = bestSeconds = fewestMoves = hintsUsed = noHintWins = 0;
    firstGame = null;
    history = [];
    _save();
    notifyListeners();
  }

  void _save() => _p.setString('stats', jsonEncode(_toJson()));

  Map<String, dynamic> _toJson() => {
    'played': played,
    'won': won,
    'streak': streak,
    'bestStreak': bestStreak,
    'lossStreak': lossStreak,
    'totalSeconds': totalSeconds,
    'wonSeconds': wonSeconds,
    'wonMoves': wonMoves,
    'bestSeconds': bestSeconds,
    'fewestMoves': fewestMoves,
    'hintsUsed': hintsUsed,
    'noHintWins': noHintWins,
    'firstGame': firstGame?.millisecondsSinceEpoch,
    'history': [for (final h in history) h.toJson()],
  };

  void _fromJson(Map<String, dynamic> j) {
    played = j['played'] as int? ?? 0;
    won = j['won'] as int? ?? 0;
    streak = j['streak'] as int? ?? 0;
    bestStreak = j['bestStreak'] as int? ?? 0;
    lossStreak = j['lossStreak'] as int? ?? 0;
    totalSeconds = j['totalSeconds'] as int? ?? 0;
    wonSeconds = j['wonSeconds'] as int? ?? 0;
    wonMoves = j['wonMoves'] as int? ?? 0;
    bestSeconds = j['bestSeconds'] as int? ?? 0;
    fewestMoves = j['fewestMoves'] as int? ?? 0;
    hintsUsed = j['hintsUsed'] as int? ?? 0;
    noHintWins = j['noHintWins'] as int? ?? 0;
    final fg = j['firstGame'] as int?;
    firstGame = fg == null ? null : DateTime.fromMillisecondsSinceEpoch(fg);
    history = [for (final h in (j['history'] as List? ?? [])) GameRecord.fromJson(h as Map<String, dynamic>)];
  }
}
