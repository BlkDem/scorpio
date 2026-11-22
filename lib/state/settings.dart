import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Оформление стола (сукно).
class TableDesign {
  final String name;
  final Color center;
  final Color edge;
  final Color fiber;

  const TableDesign(this.name, this.center, this.edge, this.fiber);

  static const all = [
    TableDesign('Зелёное сукно', Color(0xFF1C7A43), Color(0xFF06331A), Color(0xFF7FD3A0)),
    TableDesign('Синее сукно', Color(0xFF1F5592), Color(0xFF081C38), Color(0xFF8DB6EA)),
    TableDesign('Бордовое сукно', Color(0xFF842536), Color(0xFF2A070E), Color(0xFFE59AA6)),
    TableDesign('Графит', Color(0xFF3E444C), Color(0xFF0E1013), Color(0xFFB5BCC6)),
  ];
}

class Settings extends ChangeNotifier {
  final SharedPreferences _p;

  Settings._(this._p);

  static Future<Settings> load(SharedPreferences p) async => Settings._(p);

  int get backIndex => _p.getInt('back') ?? 0;
  set backIndex(int v) => _set(() => _p.setInt('back', v));

  int get tableIndex => _p.getInt('table') ?? 0;
  set tableIndex(int v) => _set(() => _p.setInt('table', v));

  bool get solvableOnly => _p.getBool('solvable') ?? true;
  set solvableOnly(bool v) => _set(() => _p.setBool('solvable', v));

  bool get tapToMove => _p.getBool('tap') ?? true;
  set tapToMove(bool v) => _set(() => _p.setBool('tap', v));

  bool get sound => _p.getBool('sound') ?? true;
  set sound(bool v) => _set(() => _p.setBool('sound', v));

  bool get haptics => _p.getBool('haptics') ?? true;
  set haptics(bool v) => _set(() => _p.setBool('haptics', v));

  bool get showTimer => _p.getBool('timer') ?? true;
  set showTimer(bool v) => _set(() => _p.setBool('timer', v));

  bool get highlightMoves => _p.getBool('hl') ?? true;
  set highlightMoves(bool v) => _set(() => _p.setBool('hl', v));

  TableDesign get table => TableDesign.all[tableIndex.clamp(0, TableDesign.all.length - 1)];

  void _set(Future<bool> Function() f) {
    f();
    notifyListeners();
  }
}
