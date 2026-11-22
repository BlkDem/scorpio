// Генерация иконок приложения:
// flutter test test/render/icon_render_test.dart --dart-define=ICONS=1
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scorpion/ui/art/card_painter.dart';

void paintIcon(Canvas c, double s, {bool maskable = false}) {
  final rect = Offset.zero & Size(s, s);
  final d = BackDesign.all[0];
  final r = maskable ? 0.0 : s * 0.22;
  final rr = RRect.fromRectAndRadius(rect, Radius.circular(r));
  c.save();
  c.clipRRect(rr);
  c.drawRect(rect, Paint()..shader = ui.Gradient.radial(rect.center, s * 0.75, [d.light, d.dark]));
  // Тонкий гильош-узор.
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.004
    ..color = d.line.withValues(alpha: 0.28);
  for (var k = 0; k < 36; k++) {
    c.save();
    c.translate(s / 2, s / 2);
    c.rotate(k * math.pi / 18);
    c.drawOval(Rect.fromCenter(center: Offset(s * 0.18, 0), width: s * 0.5, height: s * 0.2), line);
    c.restore();
  }
  final foil = ui.Gradient.linear(
    rect.topLeft,
    rect.bottomRight,
    const [Color(0xFFFFF0B8), Color(0xFFE2B04A), Color(0xFF9C6E1E), Color(0xFFF6D98A), Color(0xFFB8862B)],
    const [0, 0.3, 0.5, 0.72, 1],
  );
  final medal = Rect.fromCenter(center: rect.center, width: s * 0.66, height: s * 0.66);
  c.drawOval(medal, Paint()..color = d.dark.withValues(alpha: 0.9));
  c.drawOval(
    medal,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03
      ..shader = foil,
  );
  ScorpionEmblem.paint(c, medal.deflate(medal.width * 0.13), foil);
  c.restore();
}

Future<void> writeIcon(WidgetTester tester, String path, int px, {bool maskable = false}) async {
  await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    paintIcon(Canvas(rec), px.toDouble(), maskable: maskable);
    final img = await rec.endRecording().toImage(px, px);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('icons', skip: !const bool.hasEnvironment('ICONS'), (tester) async {
    const res = 'android/app/src/main/res';
    for (final (dir, px) in const [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]) {
      await writeIcon(tester, '$res/mipmap-$dir/ic_launcher.png', px);
    }
    await writeIcon(tester, 'web/icons/Icon-192.png', 192);
    await writeIcon(tester, 'web/icons/Icon-512.png', 512);
    await writeIcon(tester, 'web/icons/Icon-maskable-192.png', 192, maskable: true);
    await writeIcon(tester, 'web/icons/Icon-maskable-512.png', 512, maskable: true);
    await writeIcon(tester, 'web/favicon.png', 32);
    const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    for (final f in Directory(ios).listSync().whereType<File>().where((f) => f.path.endsWith('.png'))) {
      final m = RegExp(r'(\d+(?:\.\d+)?)x\d+(?:\.\d+)?@(\d)x').firstMatch(f.path);
      final single = RegExp(r'(\d+)x\d+@(\d)x').firstMatch(f.path) ?? m;
      if (single == null) continue;
      final px = (double.parse(single.group(1)!) * int.parse(single.group(2)!)).round();
      await writeIcon(tester, f.path, px, maskable: true);
    }
  });
}
