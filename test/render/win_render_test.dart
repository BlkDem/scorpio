import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scorpion/game/game_state.dart';
import 'package:scorpion/game/solver.dart';
import 'package:scorpion/main.dart';
import 'package:scorpion/state/game_controller.dart';
import 'package:scorpion/state/settings.dart';
import 'package:scorpion/state/sfx.dart';
import 'package:scorpion/state/stats.dart';
import 'package:scorpion/ui/settings_sheet.dart';
import 'package:scorpion/ui/stats_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_util.dart';

const out = String.fromEnvironment('OUT', defaultValue: '.');

Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await ro.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> frames(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('win flow', skip: !const bool.hasEnvironment('OUT'), (tester) async {
    await loadFonts();
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 48, bottom: 32);
    SharedPreferences.setMockInitialValues({'solvable': false});
    final prefs = await SharedPreferences.getInstance();
    final settings = await Settings.load(prefs);
    final stats = await Stats.load(prefs);
    final sfx = Sfx(settings);
    final c = GameController(settings: settings, stats: stats, sfx: sfx, prefs: prefs);
    var seed = 1;
    List<Move>? sol;
    while (true) {
      final r = ScorpionSolver(nodeLimit: 5000).solve(GameState.deal(seed));
      if (r.solved) {
        sol = r.solution;
        break;
      }
      seed++;
    }
    await c.newGame(seed: seed);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ScorpionApp(controller: c, settings: settings, stats: stats),
      ),
    );
    await frames(tester, 3500);
    var shotCollect = false;
    for (var i = 0; i < sol!.length; i++) {
      final m = sol[i];
      final before = c.state.foundations.length;
      if (m.isDeal) {
        c.dealStock();
      } else {
        expect(c.tryMove(m.from, m.index, m.to), isTrue);
      }
      await frames(tester, 500);
      if (i == sol.length ~/ 2) await shot(tester, key, 'w_mid');
      if (!shotCollect && c.state.foundations.isEmpty && c.state.findCompleted() >= 0) {
        // Сбор вот-вот начнётся.
        await tester.pump(const Duration(milliseconds: 50));
      }
      if (!shotCollect && before == 0 && c.hasPendingCollect) {
        await frames(tester, 500);
        await shot(tester, key, 'w_collect');
        shotCollect = true;
      }
    }
    await frames(tester, 1500);
    await shot(tester, key, 'w_fireworks');
    await frames(tester, 2500);
    await shot(tester, key, 'w_overlay');
    // ignore: avoid_print
    print('won=${c.won} stats played=${stats.played} won=${stats.won} seed=$seed moves=${sol.length}');

    // Статистика
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: StatsScreen(stats: stats),
        ),
      ),
    );
    await frames(tester, 1500);
    await shot(tester, key, 'w_stats');

    // Меню
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: const Color(0xFF0B3D20),
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MenuSheet(settings: settings, dealNumber: seed, onRestart: () {}, onDealByNumber: (_) {}),
            ),
          ),
        ),
      ),
    );
    await frames(tester, 300);
    await shot(tester, key, 'w_menu');
    c.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
