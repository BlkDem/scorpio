import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadFonts() async {
  final b = FontLoader('Baskerville')..addFont(rootBundle.load('assets/fonts/LibreBaskerville.ttf'));
  final p = FontLoader('Playfair')..addFont(rootBundle.load('assets/fonts/PlayfairDisplay.ttf'));
  await b.load();
  await p.load();
  // Системный шрифт вместо Roboto, чтобы в тестовых снимках был виден текст.
  for (final fam in ['Roboto', 'MaterialIcons']) {
    final path = fam == 'Roboto' ? 'C:/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf' : _iconFont();
    if (path.isEmpty || !File(path).existsSync()) continue;
    final bytes = File(path).readAsBytesSync();
    final l = FontLoader(fam)..addFont(Future.value(ByteData.sublistView(bytes)));
    await l.load();
  }
}

String _iconFont() {
  final p =
      '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter'}/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
  return p;
}

Future<void> renderToPng(WidgetTester tester, Widget w, Size size, String path, {double ratio = 2}) async {
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: w));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.runAsync(() async {
    final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await ro.toImage(pixelRatio: ratio);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
