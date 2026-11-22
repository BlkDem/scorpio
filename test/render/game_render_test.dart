import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scorpion/main.dart';
import 'package:scorpion/state/game_controller.dart';
import 'package:scorpion/state/settings.dart';
import 'package:scorpion/state/sfx.dart';
import 'package:scorpion/state/stats.dart';
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

void main() {
  testWidgets('render game', skip: !const bool.hasEnvironment('OUT'), (tester) async {
    await loadFonts();
    const w = int.fromEnvironment('W', defaultValue: 412) * 1.0;
    const h = int.fromEnvironment('H', defaultValue: 915) * 1.0;
    tester.view.physicalSize = const Size(w * 2, h * 2);
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 48, bottom: 32);
    SharedPreferences.setMockInitialValues({'solvable': false});
    final prefs = await SharedPreferences.getInstance();
    final settings = await Settings.load(prefs);
    final stats = await Stats.load(prefs);
    final sfx = Sfx(settings);
    final c = GameController(settings: settings, stats: stats, sfx: sfx, prefs: prefs);
    await c.newGame(seed: int.fromEnvironment('SEED', defaultValue: 5));
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ScorpionApp(controller: c, settings: settings, stats: stats),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 900));
    await shot(tester, key, 'g_dealing');
    for (final e in find.byType(CustomPaint).evaluate().take(12)) {
      final rb = e.renderObject as RenderBox;
      // ignore: avoid_print
      print(
        'CP ${e.widget.runtimeType} ${(e.widget as CustomPaint).painter.runtimeType} size=${rb.size} attached=${rb.attached}',
      );
    }
    // ignore: avoid_print
    print(
      'scaffold=${find.byType(Scaffold).evaluate().length} text=${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}',
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shot(tester, key, 'g_dealt');
    // Подсказка
    final hint = c.state.usefulMoves();
    // ignore: avoid_print
    print('moves: $hint');
    if (hint.isNotEmpty && !hint.first.isDeal) {
      final m = hint.first;
      c.tryMove(m.from, m.index, m.to);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 150));
      await shot(tester, key, 'g_moving');
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await shot(tester, key, 'g_moved');
    }
    // Подсказка (решатель в фоне).
    await tester.runAsync(() => c.hint());
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 700));
    await shot(tester, key, 'g_hint');
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    c.dealStock();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 250));
    await shot(tester, key, 'g_stock');
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shot(tester, key, 'g_stock_done');
    c.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
