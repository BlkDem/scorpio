import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'cards_preview.dart';
import 'render_util.dart';

void main() {
  testWidgets('render cards', skip: !const bool.hasEnvironment('OUT'), (tester) async {
    await loadFonts();
    await renderToPng(
      tester,
      const MaterialApp(debugShowCheckedModeBanner: false, home: Preview()),
      const Size(500, 760),
      const String.fromEnvironment('OUT', defaultValue: 'cards.png'),
    );
  });
}
